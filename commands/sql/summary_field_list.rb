module Sql
  class SummaryFieldList
    attr_reader :fields

    def multiple_field_group?
      @fields.size > 1
    end

    def self.summary_field?(clause)
      field_regex = %r/[+-]?[a-zA-Z.0-9_:]+%?/
      if clause =~ /^-?s(?:\s*=(\s*#{field_regex}(?:\s*,\s*#{field_regex})*))$/
        return $1 || 'name'
      end
      return nil
    end

    def initialize(s_clauses)
      field_list = SummaryFieldList.summary_field?(s_clauses)
      unless field_list
        raise StandardError.new("Malformed summary clause: #{s_clauses}")
      end

      fields = field_list.split(",").map { |field| field.strip }
      @fields = fields.map { |f| SummaryField.new(f) }

      seen_fields = Set.new
      for field in @fields
        if seen_fields.include?(field.field)
          raise StandardError.new("Repeated field #{field.field} " +
            "in summary list #{s_clauses}")
        end
      end
    end
  end
end
