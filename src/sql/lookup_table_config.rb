require 'sql/column'
require 'sql/field'

module Sql
  class LookupTableConfig
    attr_reader :name

    def initialize(config, name, lookup_cfg)
      @cfg = config
      @name = name
      @lookup_cfg = lookup_cfg
    end

    def match?(col)
      match_name?(col.name)
    end

    def match_name?(colname)
      fields.any? { |f| f.name == colname } ||
        generated_columns.any? { |f| f.name == colname }
    end

    def fields
      @fields ||= find_fields
    end

    def lookup_field(field_name)
      if match_name?(field_name)
        return self.fields[0].name.dup
      end
      field_name
    end

    def fk_field(field_name)
      if self.generated_columns.any? { |c| c.name == field_name }
        return Sql::Field.new(self.fields[0].name).reference_field
      end
      Sql::Field.new(field_name).reference_field
    end

    def generated_columns
      @generated_columns ||= find_generated_columns
    end

  private
    def find_fields
      base_fields = (@lookup_cfg.is_a?(Array) && @lookup_cfg.dup) || []
      return base_fields unless @lookup_cfg

      if @lookup_cfg.is_a?(Hash)
        base_fields += @lookup_cfg['fields'] if @lookup_cfg['fields']
      end
      base_fields.map { |f| Sql::Column.new(@cfg, f, {}) }
    end

    def find_generated_columns
      return [] if !@lookup_cfg || @lookup_cfg.is_a?(Array)
      generated_fields = @lookup_cfg['generated-fields'] || []
      generated_fields.map { |f| Sql::Column.new(@cfg, f, {}) }
    end
  end
end
