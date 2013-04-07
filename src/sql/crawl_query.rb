require 'query/sort'
require 'sql/field'
require 'sql/query_tables'
require 'sql/column_resolver'
require 'sql/field_resolver'
require 'sql/aggregate_expression'

module Sql
  class CrawlQuery
    attr_accessor :ast, :argstr, :nick, :num, :raw, :extra, :ctx
    attr_accessor :summary_sort, :table, :game
    attr_reader   :query_fields

    def initialize(ast, predicates, nick)
      @ast = ast
      @ctx = @ast.context
      @tables = QueryTables.new(@ctx.table(@ast.game))
      @original_pred = predicates.dup
      @pred = predicates.dup
      @nick = nick
      @num = @ast.game_number
      @extra = @ast.extra
      @argstr = ast.description(nick)
      @values = nil
      @random_game = nil
      @summary_sort = nil
      @sorts = ast.sorts && ast.sorts.dup
      @summarise = ast.summarise && ast.summarise.dup
      @raw = nil
      @joins = false

      with_contexts {
        resolve_predicate_columns(@pred)
        @count_pred = @pred.dup
        @summary_pred = @pred.dup

        @count_tables = @tables.dup
        @summary_tables = @tables.dup

        resolve_sort_fields(@pred, @tables)
        @query_fields = resolve_query_fields
      }
    end

    def option(key)
      @ast.option(key)
    end

    def extra=(extra)
      @extra = extra && extra.dup
    end

    def row_to_fieldmap(row)
      base_size = @ctx.db_columns.size
      extras = { }
      map = { }
      (0 ... row.size).each do |i|
        field = @query_fields[i]
        if i < base_size
          map[field.full_name] = field.log_value(row[i])
        else
          extras[field.to_s] = field.log_value(row[i])
        end
      end
      map['sql_table'] = @ctx.table
      unless extras.empty?
        map['extra_values'] = extras.map { |k, v| "#{k}=#{v}" }.join(";;;;")
      end
      map
    end

    def resolve_sort_fields(pred, tables)
      @sorts.each { |sort|
        sort.each_field { |field|
          resolve_field(field, tables)
        }
      }
    end

    def with_contexts
      GameContext.with_game(ast.game) do
        @ctx.with do
          yield
        end
      end
    end

    def resolve_predicate_columns(predicates, table_set=@tables)
      Sql::ColumnResolver.resolve(@ctx, table_set, predicates)
    end

    # When predicates are updated after initial resolution, update the
    # table sets for joins.
    def update_predicate_columns
      resolve_predicate_columns(@pred, @tables)
      resolve_predicate_columns(@summary_pred, @summary_tables)
      resolve_predicate_columns(@count_pred, @count_tables)
    end

    def select_query_fields
      fields = @ctx.db_columns.map { |c| Sql::Field.field(c.name) }
      if @extra && @extra.fields
        fields += @extra.fields.find_all { |ef|
          !ef.simple_field? && !ef.aggregate?
        }.map(&:expr)
      end
      fields
    end

    def resolve_query_fields
      self.select_query_fields.each { |field|
        resolve_field(field, @tables)
      }
    end

    # Is this a query aimed at a single nick?
    def single_nick?
      @nick != '*' && @nick !~ /^!/
    end

    def summarise
      @summarise
    end

    def summarise?
      @ast.summary?
    end

    def grouping_query?
      self.summarise
    end

    def group_count
      summarise ? summarise.arity : 0
    end

    def query_groups
      summarise ? summarise.arguments : []
    end

    def random_game?
      @random_game
    end

    def random_game=(random_game)
      @random_game = random_game
    end

    def resolve_field(field, table=@tables)
      with_contexts {
        Sql::FieldResolver.resolve(@ctx, table, field)
      }
    end

    def summarise= (s)
      raise "WTF"
      @summarise = s
      resolve_summary_fields
      @query = nil
    end

    def add_predicate(operator, pred)
      with_contexts {
        new_pred = Query::QueryStruct.new(operator, pred)
        @pred << new_pred
        @count_pred << new_pred.dup
        @summary_pred << new_pred.dup
        update_predicate_columns
      }
    end

    def select(field_expressions, with_sorts=true)
      table_context = @count_tables.dup
      with_contexts {
        select_cols = field_expressions.map { |fe|
          resolve_field(fe, table_context).to_sql
        }.join(", ")

        "SELECT #{select_cols} FROM #{table_context.to_sql} " +
           where(@pred, with_sorts)
      }
    end

    def query_columns
      with_contexts {
        self.query_fields.map { |f| f.to_sql }
      }
    end

    def select_all(with_sorts=true, single_record_index=0)
      if single_record_index > 0
        resolve_sort_fields(@count_pred, @count_tables)
        id_subquery = self.select_id(with_sorts, single_record_index)
        id_field = Sql::Field.field('id')
        id_sql = resolve_field(id_field, @tables).to_sql
        return ("SELECT #{query_columns.join(", ")} " +
                "FROM #{@tables.to_sql} WHERE #{id_sql} = (#{id_subquery})")
      end

      "SELECT #{query_columns.join(", ")} FROM #{@tables.to_sql} " +
         where(@pred, with_sorts)
    end

    def select_id(with_sorts=false, single_record_index=0)
      id_field = Sql::Field.field('id')
      id_sql = resolve_field(id_field, @count_tables).to_sql
      "SELECT #{id_sql} FROM #{@count_tables.to_sql} " +
        "#{where(@count_pred, with_sorts)} #{limit_clause(single_record_index)}"
    end

    def select_count
      "SELECT COUNT(*) FROM #{@count_tables.to_sql} " +
        where(@count_pred, false)
    end

    def limit_clause(limit)
      return '' unless limit > 0
      return "LIMIT #{limit}" if limit == 1
      "LIMIT 1 OFFSET #{limit - 1}"
    end

    def resolve_summary_fields
      if summarise
        summarise.each_field { |field|
          resolve_field(field, @summary_tables)
        }
      end

      if @extra
        @extra.each_field { |field|
          resolve_field(field, @summary_tables)
        }
      end
    end

    def summary_query
      resolve_summary_fields

      @query = nil
      sortdir = @summary_sort
      %{SELECT #{summary_fields} FROM #{@summary_tables.to_sql}
        #{where(@summary_pred, false)} #{summary_group} #{summary_order}}
    end

    def summary_order
      if summarise && !summarise.multiple_field_group?
        "ORDER BY fieldcount #{@summary_sort}"
      else
        ''
      end
    end

    def summary_db_fields
      summarise.arguments.map { |arg|
        arg.to_sql
      }
    end

    def summary_group
      summarise ? "GROUP BY #{summary_db_fields.join(',')}" : ''
    end

    def summary_fields
      basefields = ''
      extras = ''
      if summarise
        basefields = "COUNT(*) AS fieldcount, #{summary_db_fields.join(", ")}"
      end
      if @extra && !@extra.empty?
        # At this point extras must be aggregate columns.
        if !@extra.aggregate?
          raise "Extra fields (#{@extra.extra}) contain non-aggregates"
        end
        extras = @extra.fields.map { |f|
          Sql::AggregateExpression.aggregate_sql(@summary_tables, f)
        }.join(", ")
      end
      if basefields.empty? && extras.empty?
        basefields = "COUNT(*) AS fieldcount"
      end
      [basefields, extras].find_all { |x| x && !x.empty? }.join(", ")
    end

    def where(predicates, with_sorts)
      build_query(predicates, with_sorts)
    end

    def values
      raise "Must build a query first" unless @values
      @values
    end

    def version_predicate
      %{v #{OPERATORS['=~']} ?}
    end

    def build_query(predicates, with_sorts=true)
      @query, @values = predicates.to_sql, predicates.sql_values
      @query = "WHERE #{@query}" unless @query.empty?
      if with_sorts && ast.has_sorts?
        @query << " " unless @query.empty?
        @query << "ORDER BY " << ast.primary_sort.to_sql

        unless ast.primary_sort.unique_valued?
          @query << ", " <<
                 Query::Sort.new(resolve_field('id'), 'ASC').to_sql
        end
      end
      @query
    end

    def reverse
      with_contexts do
        predicate_copy = @original_pred.dup
        ast_copy = @ast.dup
        ast_copy.reverse_sorts!
        rq = CrawlQuery.new(ast_copy, predicate_copy, @nick)
        rq.table = @table
        rq
      end
    end
  end
end
