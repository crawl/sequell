require 'sql/column'

module Sql
  class LookupTableConfig
    def initialize(cfg)
      @cfg = cfg
    end

    def generated_columns
      @generated_columns ||= find_generated_columns
    end

  private
    def find_generated_columns
      generated_fields = @cfg['generated-fields'] || []
      generated_fields.map { |f| Sql::Column.new(f) }
    end
  end
end
