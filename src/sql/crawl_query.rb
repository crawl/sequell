require 'query/sort'
require 'sql/field'
require 'sql/query_tables'
require 'sql/column_resolver'
require 'sql/field_resolver'
require 'sql/aggregate_expression'
require 'formatter/json'
require 'formatter/text'

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
      @sorts = ast.sorts && ast.sorts.map(&:dup)
      @count_sorts = ast.sorts && ast.sorts.map(&:dup)
      @summarise = ast.summarise && ast.summarise.dup
      @raw = nil
      @joins = false

      with_contexts {
        @ast.autojoin_lookup_columns!
        @count_ast = @ast.dup
        @summary_ast = @ast.dup

        # Don't resolve sort fields until we've cloned the previous tables.
        resolve_sort_fields(@sorts, @ast)
        @query_fields = resolve_query_fields(@ast)
      }
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
      base_size = @ctx.db_columns.size
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
      fields = @ctx.db_columns.map { |c| Sql::Field.field(c.name) }
      if @extra && @extra.fields
        fields += @extra.fields.find_all { |ef|
          !ef.simple_field? && !ef.aggregate?
        }.map(&:expr)
      end
      fields
    end

    def resolve_query_fields(ast)
      if @extra
        res = @extra.fields.each { |extra|
          extra.each_field { |field|
            resolve_field(field, ast)
          }
        }
        res
      end
      self.select_query_fields.each { |field|
        resolve_field(field, ast)
      }
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

    def resolve_field(field, ast=@ast)
      with_contexts {
        Sql::FieldResolver.resolve(ast, field)
      }
    end

    def select(field_expressions, with_sorts=true)
      # TODO: Odd use here: @count_ast vs @ast in where clause: is this a bug?
      ast = @count_ast.dup
      with_contexts {
        select_cols = field_expressions.map { |fe|
          resolve_field(fe, ast).to_sql
        }.join(", ")

        @values = self.with_values(field_expressions, @values)
        @values += ast.table_list_values
        "SELECT #{select_cols}\n  FROM #{ast.to_table_list_sql}\n" +
           where(@ast.head, with_sorts && @sorts)
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
      if record_index > 0 && count == 1
        resolve_sort_fields(@count_sorts, @count_ast)
        id_subquery = self.select_id(with_sorts, record_index, count)
        id_field = Sql::Field.field('id')
        id_sql = resolve_field(id_field, @ast).to_sql_output
        @values = self.with_values(query_fields, @values)
        @values += self.with_values(@count_sorts)
        return ("SELECT #{query_columns.sjoin(", ")} " +
                "FROM #{ast.to_table_list_sql} WHERE #{id_sql} = (#{id_subquery})")
      end

      @values = self.with_values(query_fields, @values)
      @values += self.with_values(@sorts) if with_sorts
      "SELECT #{query_columns.join(", ")} FROM #{@ast.to_table_list_sql} " +
         where(@ast.head, with_sorts && @sorts) + " " +
         limit_clause(record_index, count)
    end

    def select_id(with_sorts=false, record_index=0, count=1)
      id_field = Sql::Field.field('id')
      id_sql = resolve_field(id_field, @count_ast).to_sql
      where_clause = self.where(@count_ast, with_sorts && @count_sorts)
      "SELECT #{id_sql} FROM #{@count_ast.to_table_list_sql} " +
        "#{where_clause} #{limit_clause(record_index, count)}"
    end

    def select_count
      "SELECT COUNT(*) FROM #{@count_ast.to_table_list_sql} " +
        where(@count_ast.head, false)
    end

    def limit_clause(record_index, count)
      return '' unless record_index > 0
      fragments = []
      fragments << "LIMIT #{count}" if count > 0
      fragments << "OFFSET #{record_index - 1}" if record_index > 1
      fragments.join(' ')
    end

    def resolve_summary_fields
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

      where_clause = where(@summary_ast.head, false)
      @values = self.with_values([summarise, extra].compact, @values)

      summary_field_text = self.summary_fields
      summary_group_text = self.summary_group
      %{SELECT #{summary_field_text} FROM #{@summary_pred.to_table_list_sql}
        #{where_clause} #{summary_group_text} #{summary_order}}
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
          Sql::AggregateExpression.aggregate_sql(@summary_pred, f)
        }.join(", ")
      end
      if basefields.empty? && extras.empty?
        basefields = "COUNT(*) AS fieldcount"
      end
      [basefields, extras].find_all { |x| x && !x.empty? }.join(", ")
    end

    def where(predicates, with_sorts)
      @aliases = { }
      build_query(predicates, with_sorts)
    end

    def values
      raise "Must build a query first" unless @values
      @values
    end

    def version_predicate
      %{v #{OPERATORS['=~']} ?}
    end

    def build_query(predicates, with_sorts=nil)
      @query, @values = predicates.to_sql_output, predicates.sql_values
      @query = "WHERE #{@query}" unless @query.empty?
      if with_sorts && !with_sorts.empty?
        @query << " " unless @query.empty?
        @query << "ORDER BY " << with_sorts.first.to_sql
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

  private

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
