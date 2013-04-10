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

    def has_format?
      ast.key_value(:fmt)
    end

    def format_game
      Tpl::Template.template_eval(ast.key_value(:fmt), self.fieldmap)
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

    def none?
      self.empty?
    end

    def fieldmap
      @fieldmap ||= row_fieldmap
    end

    def extra_field_values(map=@fieldmap)
      ev = map['extra']
      return nil unless ev
      ev.split(',').map { |v| "#{v}=#{map[v]}" }.join(';')
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
        'count' => self.count,
        'x' => self.extra_field_values(rowmap))
    end
  end
end
