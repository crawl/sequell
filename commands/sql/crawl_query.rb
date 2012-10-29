require 'query/query_struct'
require 'query/sort'
require 'sql/field'
require 'sql/query_tables'
require 'sql/field_predicate'
require 'sql/column_resolver'
require 'sql/field_resolver'

module Sql
  class CrawlQuery
    attr_accessor :argstr, :nick, :num, :raw, :extra_fields, :ctx
    attr_accessor :summary_sort, :table, :game
    attr_reader   :query_fields

    def initialize(predicates, extra_fields, nick, num, argstr)
      @tables = QueryTables.new(QueryContext.context.table)
      @pred = predicates
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

      resolve_predicate_columns(predicates)

      @count_tables = @tables.dup
      @summary_tables = @tables.dup

      resolve_sort_fields
      @query_fields = resolve_query_fields
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
      resolve_predicate_columns(@pred, @summary_tables)
      resolve_predicate_columns(@pred, @count_tables)
    end

    def resolve_query_fields
      @ctx.db_columns.map { |c| Sql::Field.new(c.name) }.each { |field|
        resolve_field(field, @tables)
      }
    end

    # Is this a query aimed at a single nick?
    def single_nick?
      @nick != '*'
    end

    def summarise
      @summarise
    end

    def summarise?
      @summarise || (@extra_fields && @extra_fields.aggregate?)
    end

    def random_game?
      @random_game
    end

    def random_game=(random_game)
      @random_game = random_game
    end

    def resolve_field(field, table)
      with_contexts {
        Sql::FieldResolver.resolve(@ctx, table, field)
      }
    end

    def summarise= (s)
      @summarise = s

      for summary_field in @summarise.fields
        fieldname = summary_field.field
        if @ctx.value_key?(fieldname)
          verb = @ctx.key_field
          # Ulch, we have to modify our predicates.
          add_predicate('AND',
                        Sql::FieldPredicate.predicate(fieldname, '=', verb))
          summary_field.field = Sql::Field.field(@ctx.value_field)

          # Resolve the verb field in both the summary and normal tables.
          update_predicate_columns
        end
      end

      resolve_summary_fields
      @query = nil
    end

    def add_predicate(operator, pred)
      @pred << Query::QueryStruct.new(operator, pred)
    end

    def select(field_expressions, with_sorts=true)
      with_contexts {
        field_expressions.each { |field_expr|
          resolve_field(field_expr.field, @tables)
        }

        select_cols = field_expressions.map { |fe|
          fe.to_sql(@tables, @ctx)
        }.join(", ")

        "SELECT #{select_cols} FROM #{@tables.to_sql} " + where(with_sorts)
      }
    end

    def query_columns
      with_contexts {
        self.query_fields.map { |f| @ctx.dbfield(f, @tables) }
      }
    end

    def select_all
      "SELECT #{query_columns.join(", ")} FROM #{@tables.to_sql} " + where
    end

    def select_count
      "SELECT COUNT(*) FROM #{@count_tables.to_sql} " + where(false)
    end

    def resolve_summary_fields
      if @summarise
        @summarise.fields.each { |summary_field|
          resolve_field(summary_field.field, @summary_tables)
        }
      end

      if @extra_fields
        @extra_fields.fields.each { |extra_field|
          resolve_field(extra_field.field, @summary_tables)
        }
      end
    end

    def summary_query
      resolve_summary_fields

      temp = @pred.sorts
      begin
        @pred.sorts = []
        @query = nil
        sortdir = @summary_sort
        %{SELECT #{summary_fields} FROM #{@summary_tables.to_sql}
          #{where} #{summary_group} #{summary_order}}
      ensure
        @pred.sorts = temp
      end
    end

    def summary_order
      if @summarise && !@summarise.multiple_field_group?
        "ORDER BY fieldcount #{@summary_sort}"
      else
        ''
      end
    end

    def summary_db_fields
      @summarise.fields.map { |f| @ctx.dbfield(f.field, @tables) }
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
          f.to_sql(@summary_tables)
        }.join(", ")
      end
      [basefields, extras].find_all { |x| x && !x.empty? }.join(", ")
    end

    def query(with_sorts=true)
      build_query(with_sorts)
    end

    def values
      build_query unless @values
      @values || []
    end

    def version_predicate
      %{v #{OPERATORS['=~']} ?}
    end

    def build_query(with_sorts=true)
      @query, @values = @pred.to_sql(@tables, @ctx), @pred.sql_values
      @query = "WHERE #{@query}" unless @query.empty?
      if with_sorts && @pred.has_sorts?
        @query << " " unless @query.empty?
        @query << "ORDER BY " << @pred.primary_sort.to_sql(@tables)

        unless @ctx.unique_valued?(@pred.primary_sort.field)
          @query << ", " <<
                 Query::Sort.new(Sql::Field.new('id'), 'ASC').to_sql(@tables)
        end
      end
      @query
    end

    alias where query

    def reverse
      predicate_copy = @pred.dup
      predicate_copy.reverse_sorts!
      rq = CrawlQuery.new(predicate_copy, @extra_fields,
                          @nick, @num, @argstr)
      rq.table = @table
      rq
    end
  end
end
