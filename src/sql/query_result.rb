module Sql
  class QueryResult
    attr_accessor :index, :count, :result, :query

    alias :n :index

    def self.none(query)
      self.new(nil, nil, nil, query)
    end

    def initialize(index, count, result, query)
      @index = index
      @count = count || 0
      @result = result
      @query = query
    end

    def ast
      query.ast
    end

    def ctx
      ast.context
    end

    def has_format?
      ast.key_value(:fmt)
    end

    def format_game
      rowmap = self.fieldmap
      rowmap.merge!(split_hash(rowmap['extra_values']))
      extras = {
        'x' => self.extra_field_values(rowmap),
        '@x' => self.extra_value_array(rowmap)
      }
      Tpl::Template.template_eval_string(ast.key_value(:fmt),
        ast.template_properties.merge(rowmap).merge(extras))
    end

    def option(key)
      query.option(key)
    end

    def milestone?
      game['milestone']
    end

    def game_key
      @game_key ||= game['game_key']
    end

    def milestone_game
      raise StandardError, "Not a milestone" unless milestone?
      @milestone_game ||=
        self.game_key && sql_game_by_key(self.game_key, ast.extra)
    end

    def qualified_index
      if index < count
        "#{index}/#{count}"
      else
        index.to_s
      end
    end

    def query_arguments
      @query && @query.argstr
    end

    def empty?
      @result.nil?
    end
    alias :none? :empty?

    def fieldmap
      @fieldmap ||= row_fieldmap
    end

    def extra_fields(map=self.fieldmap)
      ev = map['extra']
      return [] unless ev
      ev.split(';;;;')
    end

    def extra_value_array(map=self.fieldmap)
      extra_fields(map).map { |v| map[v] }
    end

    def extra_field_values(map=self.fieldmap)
      extra_fields(map).map { |v| "#{v}=#{map[v]}" }.join(';')
    end

    def as_json
      fieldmap
    end

    def format_string
      if has_format?
        format_game
      else
        print_game_n(self.qualified_index, self.game)
      end
    end

    alias :game :fieldmap

  private
    def row_fieldmap
      return nil unless @result
      rowmap = @query.row_to_fieldmap(@result)
      rowmap.merge(
        'qualified_index' => self.qualified_index,
        'index' => self.index,
        'n' => self.count,
        'count' => self.count)
    end

    def split_hash(values)
      return { } unless values
      map = { }
      values.split(';;;;').each { |kv|
        if kv =~ /^(.*)@=@(.*)/
          map[$1] = $2
        end
      }
      map
    end
  end
end
