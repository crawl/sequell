require 'sql/column'

module Sql
  class ColumnList
    def initialize(config, column_list)
      @config = config
      @column_list = column_list
      @columns = column_list.map { |column_config|
        Sql::Column.new(config, column_config)
      }
    end

    def columns
      @columns
    end

    def [](column_name)
      self.column_map[column_name]
    end

    def type(field_name)
      field = self[field_name]
      field && field.type
    end

    def column_map
      @column_map ||= Hash[ @columns.map { |c| [c.name, c] } ]
    end
  end
end
