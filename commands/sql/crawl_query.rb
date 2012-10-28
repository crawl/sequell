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

      check_joins(predicates) if @ctx == CTX_STONE
      resolve_predicate_columns(predicates)

      @count_tables = @tables.dup
      @summary_tables = @tables.dup
      @query_fields = resolve_query_fields
    end

    def with_contexts
      GameContext.with_game(@game) do
        @ctx.with do
          yield
        end
      end
    end

    def resolve_predicate_columns(predicates)
      Sql::ColumnResolver.resolve(@ctx, @tables, predicates)
    end

    def resolve_query_fields
      @ctx.db_columns.map { |c| Sql::Field.new(c.name) }.each { |field|
        Sql::FieldResolver.resolve(@ctx, @tables, field)
      }
    end

    def has_joins?(preds)
      return false if preds.empty? || !preds.is_a?(Array)
      if preds[0].is_a?(Symbol)
        return preds[3] =~ /^#{CTX_LOG.table_alias}\./
      end
      preds.any? { |x| has_joins?(x) }
    end

    def fixup_join
      return if @joins

      @joins = true
      game_key = Sql::Field.new('game_key')
      ref_key = @ctx.field_ref(game_key)
      @tables.join(Join.new(@tables.primary_table, CTX_LOG.table,
                            ref_key, ref_key))
    end

    def sort_joins?
      @pred.sorts.any? { |s| not @ctx.local_field_def(s.field) }
    end

    def check_joins(preds)
      if has_joins?(preds) || sort_joins?
        fixup_join()
      end
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

    def summarise= (s)
      @summarise = s

      need_join = false
      for summary_field in @summarise.fields
        fieldname = summary_field.field
        if @ctx.value_key?(fieldname)
          verb = @ctx.key_field
          # Ulch, we have to modify our predicates.
          add_predicate('AND',
                        Sql::FieldPredicate.predicate(fieldname, '=', verb))
          summary_field.field = noun
        end

        # If this is not a local field, we need a join.
        if !QueryContext.context.local_field_def(summary_field.field)
          fixup_join()
        end
      end

      @summarise.fields.each { |summary_field|
        Sql::FieldResolver.resolve(@ctx, @summary_tables, summary_field.field)
      }

      @query = nil
    end

    def add_predicate(operator, pred)
      @pred << QueryStruct.new(operator, pred)
    end

    def select(what, with_sorts=true)
      "SELECT #{what} FROM #{@tables.to_sql} " + where(with_sorts)
    end

    def query_columns
      self.query_fields.map { |f| @ctx.dbfield(f, @tables) }
    end

    def select_all
      "SELECT #{query_columns.join(", ")} FROM #{@tables.to_sql} " + where
    end

    def select_count
      "SELECT COUNT(*) FROM #{@count_tables.to_sql} " + where(false)
    end

    def summary_query
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
        extras = @extra_fields.fields.map { |f| f.to_s }.join(", ")
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
      rq = CrawlQuery.new(@pred, reverse_sorts(@sort), @extra_fields,
                          @nick, @num, @argstr)
      rq.table = @table
      rq
    end

    def clear_sorts!
      @sort.clear
      @query = nil
    end

    def reverse_sorts(sorts)
      sorts.map do |s|
        s.reverse
      end
    end
  end
end
