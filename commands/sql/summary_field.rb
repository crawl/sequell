module Sql
  class SummaryField
    attr_accessor :order, :field, :percentage

    def initialize(s_clause)
      unless s_clause =~ /^([+-]?)(\S+?)(%?)$/
        raise StandardError.new("Malformed summary clause: #{s_clause}")
      end
      @order = $1.empty? ? '+' : $1
      @field = Sql::Field.new($2)
      unless QueryContext.context.summarise?(@field)
        raise StandardError.new("Cannot summarise by #{@field}")
      end
      @percentage = !$3.empty?
    end

    def descending?
      @order == '+'
    end

    def sort_field
      "#{order}#{field}"
    end
  end
end
