require 'query/query_struct'
require 'query/sort'
require 'sql/field'
require 'sql/query_tables'
require 'sql/field_predicate'
require 'sql/column_resolver'
require 'sql/field_resolver'
require 'sql/aggregate_expression'

module Sql
  class CrawlQuery
    attr_accessor :argstr, :nick, :num, :raw, :extra_fields, :ctx
    attr_accessor :summary_sort, :table, :game
    attr_reader   :query_fields

    def initialize(predicates, extra_fields, nick, num, argstr)
      @tables = QueryTables.new(QueryContext.context.table)
      @original_pred = predicates
      @pred = predicates.dup
      @nick = nick
      @num = num
      @extra_fields = extra_fields
      @argstr = argstr
      @values = nil
      @summarise = nil
      @random_game = nil
      @summary_sort = nil
      @raw = nil
      @joins = false
      @ctx = QueryContext.context
      @game = GameContext.game

      resolve_predicate_columns(@pred)

      @count_pred = @pred.dup
      @summary_pred = @pred.dup

      @count_tables = @tables.dup
      @summary_tables = @tables.dup

      resolve_sort_fields
      @query_fields = resolve_query_fields
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

    def resolve_sort_fields
      @pred.sorts.each { |sort|
        resolve_field(sort.field, @tables)
      }
    end

    def with_contexts
      GameContext.with_game(@game) do
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
      if @extra_fields && @extra_fields.fields
        fields += @extra_fields.fields.find_all { |ef|
          !ef.simple_field? && !ef.aggregate?
        }.map { |qf| qf.field }
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
      @summarise || (@extra_fields && @extra_fields.aggregate?)
    end

    def grouping_query?
      @summarise
    end

    def group_count
      @summarise ? @summarise.fields.size : 0
    end

    def query_groups
      @summarise ? @summarise.fields : []
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

    def resolve_value_key(expr)
      if expr.value_key?
        verb = @ctx.key_field
        # Ulch, we have to modify our predicates.
        add_predicate('AND',
                      Sql::FieldPredicate.predicate(expr.name, '=', verb))
        expr.field = Sql::FieldExprParser.expr(@ctx.value_field)
      end
    end

    def summarise= (s)
      @summarise = s

      for summary_field in @summarise.fields
        self.resolve_value_key(summary_field)
      end

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

    def select_all(with_sorts=true)
      "SELECT #{query_columns.join(", ")} FROM #{@tables.to_sql} " +
         where(@pred, with_sorts)
    end

    def select_id(with_sorts=false)
      id_field = Sql::Field.field('id')
      id_sql = resolve_field(id_field, @count_tables).to_sql
      "SELECT #{id_sql} FROM #{@count_tables.to_sql} " +
        "#{where(@count_pred, with_sorts)}"
    end

    def select_count
      "SELECT COUNT(*) FROM #{@count_tables.to_sql} " +
        where(@count_pred, false)
    end

    def resolve_summary_fields
      if @summarise
        @summarise.fields.each { |summary_field|
          resolve_field(summary_field.field, @summary_tables)
        }
      end

      if @extra_fields
        @extra_fields.fields.each { |extra_field|
          self.resolve_value_key(extra_field)
          resolve_field(extra_field.field, @summary_tables)
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
      if @summarise && !@summarise.multiple_field_group?
        "ORDER BY fieldcount #{@summary_sort}"
      else
        ''
      end
    end

    def summary_db_fields
      @summarise.fields.map { |f|
        f.field.to_sql
      }
    end

    def summary_group
      @summarise ? "GROUP BY #{summary_db_fields.join(',')}" : ''
    end

    def summary_fields
      basefields = ''
      extras = ''
      if @summarise
        basefields = "COUNT(*) AS fieldcount, #{summary_db_fields.join(", ")}"
      end
      if @extra_fields && !@extra_fields.empty?
        # At this point extras must be aggregate columns.
        if !@extra_fields.aggregate?
          raise "Extra fields (#{@extra_fields.extra}) contain non-aggregates"
        end
        extras = @extra_fields.fields.map { |f|
          Sql::AggregateExpression.aggregate_sql(@summary_tables, f)
        }.join(", ")
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
      @query, @values = predicates.to_sql(@tables, @ctx), predicates.sql_values
      @query = "WHERE #{@query}" unless @query.empty?
      if with_sorts && predicates.has_sorts?
        @query << " " unless @query.empty?
        @query << "ORDER BY " << predicates.primary_sort.to_sql(@tables)

        unless predicates.primary_sort.unique_valued?
          @query << ", " <<
                 Query::Sort.new(resolve_field('id'), 'ASC').to_sql(@tables)
        end
      end
      @query
    end

    def reverse
      with_contexts do
        predicate_copy = @original_pred.dup
        predicate_copy.reverse_sorts!
        rq = CrawlQuery.new(predicate_copy, @extra_fields,
                            @nick, @num, @argstr)
        rq.table = @table
        rq
      end
    end
  end
end
