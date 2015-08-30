require 'query/sort'
require 'sql/field'
require 'sql/query_tables'
require 'sql/column_resolver'
require 'sql/field_resolver'
require 'sql/aggregate_expression'
require 'formatter/json'
require 'formatter/text'
require 'ostruct'

module Sql
  class CrawlQuery
    attr_accessor :ast, :argstr, :nick, :num, :raw, :extra, :ctx
    attr_accessor :summary_sort, :table, :game
    attr_reader   :query_fields

    MAX_ROW_COUNT = 1000

    def initialize(ast)
      @ast = ast
      @ctx = @ast.context

      @original_query = @ast.dup
      @nick = ast.default_nick
      @num = @ast.game_number
      self.extra = ast.extra
      @argstr = ast.description(nick)
      @values = nil
      @random_game = nil
      @summary_sort = nil
      @sorts = ast.order.dup
      @raw = nil
      @joins = false

      @ast.autojoin_lookup_columns!
      @count_ast = @ast.dup
      @count_sorts = @count_ast.order.dup
      @summary_ast = @ast.dup
      @summarise = @summary_ast.summarise

      # Don't resolve sort fields until we've cloned the previous tables.
      resolve_sort_fields(@sorts, @ast)
      @query_fields = resolve_query_fields(@ast)
    end

    def formatter
      @formatter ||= create_formatter
    end

    def stub_message
      ast.stub_message(self.nick)
    end

    def title
      @ast.description(ast.default_nick, context: true, meta: true, tail: true,
                       no_parens: true)
    end

    def option(key)
      @ast.option(key)
    end

    def summarise?
      @ast.summary?
    end

    def grouping_query?
      self.summarise
    end

    def json?
      @json || option(:json)
    end

    def json=(json)
      ast.set_option(:json, json)
    end

    def count?
      option(:count)
    end

    def requested_row_count
      @requested_row_count ||= check_row_count
    end

    def extra=(extra)
      # FIXME: Break these up.
      @extra = extra && extra.dup
      @count_extra = extra && extra.dup
      @summary_extra = extra && extra.dup
    end

    def row_to_fieldmap(row)
      base_size = @ctx.default_select_fields.size
      extras = { }
      map = { }
      row = row.to_a
      (0 ... row.size).each do |i|
        field = @query_fields[i]
        if i < base_size
          map[field.full_name] = field.log_value(row[i])
        else
          extras[field.to_s] = field.log_value(row[i])
        end
      end
      map['file_cv'] = (map['file'] || '').sub(/.*-([^-]+)$/, '\1')
      map['sql_table'] = @ctx.table
      unless extras.empty?
        map['extra_values'] = extras.map { |k, v| "#{k}@=@#{v}" }.join(";;;;")
      end
      add_extra_fields_to_xlog_record(map)
    end

    def resolve_sort_fields(sorts, tables)
      sorts.each { |sort|
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

    def select_query_fields
      fields = @ctx.default_select_fields
      known_fields = Set.new(fields.map(&:name))

      if @extra && @extra.fields
        fields += @extra.fields.find_all { |ef|
          (!ef.simple_field? || !known_fields.include?(ef.expr.name)) && !ef.aggregate?
        }.map(&:expr)
      end
      fields
    end

    # Is this a query aimed at a single nick?
    def single_nick?
      @nick != '*' && @nick !~ /^!/
    end

    def summarise
      @summarise
    end

    def group_count
      summarise ? summarise.arity : 0
    end

    def query_groups
      summarise ? summarise.arguments : []
    end

    def random_game?
      @ast.random?
    end

    def resolve_field(field, ast)
      Sql::FieldResolver.resolve(ast, ast.bind(Sql::Field.field(field)))
    end

    def select(field_expressions, with_sorts=true)
      ast = @count_ast.dup
      with_contexts {
        select_cols = field_expressions.map { |fe|
          resolve_field(fe, ast).to_sql
        }.join(", ")

        @values = self.with_values(field_expressions, @values)
        @values += ast.table_list_values

        where_values = where(ast, with_sorts && @sorts)
        query = "SELECT #{select_cols}\n  FROM #{ast.to_table_list_sql}\n" +
                where_values.where_clause
        @values += where_values.values
        query
      }
    end

    def with_values(expressions, values=[])
      new_values = []
      if expressions
        new_values = expressions.map(&:sql_values).flatten
      end
      new_values + (values || [])
    end

    def query_columns
      with_contexts {
        self.query_fields.map { |f|
          f.to_sql_output
        }
      }
    end

    ##
    # select_all returns a query to retrieve one or more game/milestone records.
    # When +record_index+ is non-zero, an OFFSET clause is used for that
    #      (index - 1)
    # When +count+ is non-zero a LIMIT clause is used for that count.
    def select_all(with_sorts=true, record_index=0, count=1)
      if record_index > 0 && count == 1 && @ast.simple_from_clause?
        resolve_sort_fields(@count_sorts, @count_ast)
        @values = []
        id_subquery = self.select_id(with_sorts, record_index, count)
        id_values = @values.dup
        id_field = Sql::Field.field('id')
        id_sql = resolve_field(id_field, @ast).to_sql_output
        @values = []
        @values = self.with_values(query_fields, @values)
        @values += self.with_values(@count_sorts)
        table_list_sql = @ast.to_table_list_sql
        @values += @ast.table_list_values
        @values += id_values

        result = ("SELECT #{query_columns.join(", ")} " +
                  "FROM #{table_list_sql} WHERE #{id_sql} = (#{id_subquery})")

        return result
      end

      @values = self.with_values(query_fields, @values)
      @values += @ast.table_list_values

      where_clause = where(@ast, with_sorts && @sorts)
      @values += where_clause.values

      @values += self.with_values(@sorts) if with_sorts

      query_text = "SELECT #{query_columns.join(", ")} FROM #{@ast.to_table_list_sql} " +
         where_clause.where_clause + " " +
         limit_clause(record_index, count)
      query_text
    end

    def select_id(with_sorts=false, record_index=0, count=1)
      id_field = Sql::Field.field('id')
      id_sql = resolve_field(id_field, @count_ast).to_sql
      @values = @count_ast.table_list_values
      where_values = where(@count_ast, with_sorts && @count_sorts)
      @values += where_values.values
      "SELECT #{id_sql} FROM #{@count_ast.to_table_list_sql} " +
        "#{where_values.where_clause} #{limit_clause(record_index, count)}"
    end

    def select_count
      # This sequencing is important: generating the where clause may autojoin
      # tables that must be included in the table list.
      where = count_where.where_clause
      table_list = @count_ast.to_table_list_sql
      "SELECT COUNT(*) FROM #{table_list} #{where}"
    end

    def count_values
      @count_ast.table_list_values + count_where.values
    end

    def limit_clause(record_index, count)
      return '' unless record_index > 0
      fragments = []
      fragments << "LIMIT #{count}" if count > 0
      fragments << "OFFSET #{record_index - 1}" if record_index > 1
      fragments.join(' ')
    end

    def resolve_summary_fields
      STDERR.puts("Summary AST: #{@summary_ast.inspect}")
      if summarise
        summarise.each_field { |field|
          resolve_field(field, @summary_ast)
        }
      end

      if @summary_extra
        @summary_extra.each_field { |field|
          resolve_field(field, @summary_ast)
        }
      end
    end

    def summary_query
      resolve_summary_fields

      @query = nil
      sortdir = @summary_sort

      @values = self.with_values([summarise, extra].compact, @values)

      summary_field_text = self.summary_fields
      summary_group_text = self.summary_group
      %{SELECT #{summary_field_text} FROM #{@summary_ast.to_table_list_sql}
        #{summary_where.where_clause} #{summary_group_text} #{summary_order}}
    end

    def summary_values
      @summary_ast.table_list_values + summary_where.values
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
        if arg.simple?
          arg.to_sql_output
        else
          aliased_summary_field(arg)
        end
      }
    end

    def aliased_summary_field(expr)
      expr_alias = @aliases[expr.to_s]
      return expr_alias if expr_alias
      expr_alias = unique_alias(expr)
      expr.to_sql_output + " AS #{expr_alias}"
    end

    def unique_alias(expr)
      base = expr.to_s.gsub(/[^a-zA-Z]/, '_').gsub(/_+$/, '') + '_alias'
      while @aliases.values.include?(base)
        base += "_0" unless base =~ /_\d+$/
        base = base.gsub(/(\d+)$/) { |m| ($1.to_i + 1).to_s }
      end
      @aliases[expr.to_s] = base
      base
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
      if @summary_extra && !@summary_extra.empty?
        # At this point extras must be aggregate columns.
        if !@summary_extra.aggregate?
          raise "Extra fields (#{@summary_extra}) contain non-aggregates"
        end
        extras = @summary_extra.fields.map { |f|
          Sql::AggregateExpression.aggregate_sql(@summary_ast, f)
        }.join(", ")
      end
      if basefields.empty? && extras.empty?
        basefields = "COUNT(*) AS fieldcount"
      end
      [basefields, extras].find_all { |x| x && !x.empty? }.join(", ")
    end

    def values
      raise "Must build a query first" unless @values
      @values
    end

    def version_predicate
      %{v #{OPERATORS['=~']} ?}
    end

    def reverse
      with_contexts do
        predicate_copy = @original_query.dup
        ast_copy = @ast.dup
        ast_copy.reverse_sorts!
        rq = CrawlQuery.new(ast_copy)
        rq.table = @table
        rq
      end
    end

  private

    def build_query(ast, with_sorts=nil)
      query, values = ast.head.to_sql_output, ast.head.sql_values
      query = "WHERE #{query}" unless query.empty?
      if with_sorts && !with_sorts.empty?
        query << " " unless query.empty?
        query << "ORDER BY " << with_sorts.first.to_sql
        unless ast.primary_sort.unique_valued?
          query << ", " <<
            Query::Sort.new(resolve_field('id', ast), 'ASC').to_sql
        end
      end
      OpenStruct.new(where_clause: query, values: values)
    end

    def where(ast, with_sorts)
      @aliases = { }
      build_query(ast, with_sorts)
    end

    def summary_where
      @summary_where ||= where(@summary_ast, false)
    end

    def count_where
      @count_where ||= where(@count_ast, false)
    end

    def check_row_count
      c = option(:count)
      return 1 unless c
      count = (c.option_arguments.first || '1').to_i
      count = 1 if count <= 0
      if count > MAX_ROW_COUNT
        raise "row count greater than maximum (#{MAX_ROW_COUNT})"
      end
      count
    end

    def add_extra_fields_to_xlog_record(xlog_record)
      if extra && !extra.empty? && xlog_record
        field_expr = extra.fields.map(&:to_s)
        field_expr = field_expr.join(';;;;') unless json?
        xlog_record['extra'] = field_expr
      end
      xlog_record
    end

    def resolve_query_fields(ast)
      if @extra
        res = @extra.fields.each { |extra|
          extra.each_field { |field|
            resolve_field(field, ast)
          }
        }
      end
      fields = self.select_query_fields
      fields = fields.map { |field|
        field.each_field { |f| resolve_field(f, ast) }
      }
      fields
    end

    def create_formatter
      case
      when json?
        Formatter::JSON
      else
        Formatter::Text
      end
    end
  end
end
