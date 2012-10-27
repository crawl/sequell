require 'query/sort'
require 'sql/field'

module Sql
  class CrawlQuery
    attr_accessor :argstr, :nick, :num, :raw, :extra_fields, :ctx
    attr_accessor :summary_sort, :table, :game

    def initialize(predicates, sorts, extra_fields, nick, num, argstr)
      @table = QueryContext.context.table
      @pred = predicates
      @sort = sorts
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
    end

    def with_contexts
      GameContext.with_game(@game) do
        @ctx.with do
          yield
        end
      end
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
      @table = "#@table, #{CTX_LOG.table}"
      stone_alias = CTX_STONE.table_alias
      log_alias = CTX_LOG.table_alias
      add_predicate('AND',
        const_pred("#{stone_alias}.game_key = #{log_alias}.game_key"))
    end

    def sort_joins?
      talias = CTX_LOG.table_alias
      @sort.any? { |s| s =~ /ORDER BY #{talias}\./ }
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
        if QueryContext.context.noun_verb[fieldname]
          noun, verb = QueryContext.context.noun_verb_fields
          # Ulch, we have to modify our predicates.
          add_predicate('AND', field_pred(fieldname, '=', verb))
          summary_field.field = noun
        end

        # If this is not a directly summarisable field, we need a join.
        if !QueryContext.context.summarisable[summary_field.field]
          fixup_join()
        end
      end

      @query = nil
    end

    def add_predicate(operator, pred)
      if @pred[0] == operator
        @pred << pred
      else
        @pred = [ operator, @pred, pred ]
      end
    end

    def select(what, with_sorts=true)
      "SELECT #{what} FROM #@table " + where(with_sorts)
    end

    def select_all
      fields = QueryContext.context.db_field_names.join(", ")
      "SELECT #{fields} FROM #@table " + where
    end

    def select_count
      "SELECT COUNT(*) FROM #@table " + where(false)
    end

    def summary_query
      temp = @sort
      begin
        @sort = []
        @query = nil
        sortdir = @summary_sort
        %{SELECT #{summary_fields} FROM #@table
        #{where} #{summary_group} #{summary_order}}
      ensure
        @sort = temp
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
      @summarise.fields.map { |f| QueryContext.context.dbfield(f.field) }
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
      @query, @values = collect_clauses(@pred)
      @query = "WHERE #{@query}" unless @query.empty?
      unless @sort.empty? or !with_sorts
        @query << " " unless @query.empty?
        @query << "ORDER BY " << @sort[0].to_sql
        @query << ", " << Query::Sort.new(Sql::Field.new('id'), 'ASC').to_sql
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

    def sort_by! (*fields)
      clear_sorts!
      sort = ""
      for field, direction in fields
        sort << ", " unless sort.empty?
        sort << "#{field} #{direction == :desc ? 'DESC' : ''}"
      end
      @sort << "ORDER BY #{QueryContext.context.dbfield(sort)}"
    end

    def reverse_sorts(sorts)
      sorts.map do |s|
        s =~ /\s+DESC\s*$/i ? s.sub(/\s+DESC\s*$/, '') : s + " DESC"
      end
    end

    def collect_clauses(preds)
      clauses = ''
      return clauses unless preds.size > 1

      op = preds[0]
      return [ preds[1], [ preds[2] ] ] if op == :field
      return [ preds[1], [ ] ] if op == :const

      values = []

      preds[1 .. -1].each do |p|
        clauses << " " << op << " " unless clauses.empty?

        subclause, subvalues = collect_clauses(p)
        if p[0].is_a?(Symbol)
          clauses << subclause
        else
          clauses << "(#{subclause})"
        end
        values += subvalues
      end
      [ clauses, values ]
    end
  end
end
