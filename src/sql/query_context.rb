require 'sql/field'

module Sql
  class QueryContext
    @@global_context = nil

    def self.context
      @@global_context
    end

    def self.context=(ctx)
      @@global_context = ctx
    end

    attr_accessor :entity_name
    attr_accessor :fields, :synthetic, :defsort
    attr_accessor :table_alias
    attr_reader   :raw_time_field
    attr_reader   :key_field, :value_field
    attr_reader   :alt

    def with
      old_context = @@global_context
      begin
        @@global_context = self
        yield
      ensure
        @@global_context = old_context
      end
    end

    def db_columns
      @fields.columns
    end

    def field?(field)
      self.field_def(field) || self.value_key?(field)
    end

    def function?(function)
      self.function_type(function)
    end

    def function_def(function)
      @config.functions.function(function)
    end

    def function_type(function)
      @config.functions.function_type(function)
    end

    def function_expr(function)
      @config.functions.function_expr(function)
    end

    def canonical_value_key(field)
      @value_keys && @value_keys.canonicalize(field.to_s)
    end

    def value_key?(field)
      self.canonical_value_key(field)
    end

    def local_field_def(field)
      field = Sql::FieldExprParser.expr(field)
      (!field.prefixed? || field.has_prefix?(@table_alias)) &&
        (@fields[field.name] || @synthetic[field.name])
    end

    # Given a field, returns a field that references this field in a
    # join table, if the field is a local field that is a reference type.
    def field_ref(field)
      local_column = self.local_field_def(field)
      return field unless local_column && local_column.reference?
      field.reference_field
    end

    def table_qualified(field)
      fdef = self.local_field_def(field)
      if fdef
        clone = field.dup
        clone.table = Sql::QueryTable.new(self.table)
        return clone
      elsif @alt
        return @alt.table_qualified(field)
      end
      field
    end

    def field_def(field)
      return nil unless field
      field = Sql::Field.field(field)
      if field.prefixed?
        if field.has_prefix?(@table_alias)
          @fields[field.name] || @synthetic[field.name]
        else
          @alt && @alt.field_def(field)
        end
      else
        @fields[field.name] || @synthetic[field.name] ||
          (@alt && @alt.field_def(field))
      end
    end

    def table
      GAME_PREFIXES[GameContext.game] + @table
    end

    def field_table(field)
      return field.table if field.table
      if self.local_field_def(field)
        self.table
      elsif @alt && @alt.local_field_def(field)
        @alt.table
      else
        raise "Unknown field: #{field}"
      end
    end

    def db_column_expr(fdef, table_set)
      table = table_set.table(self.table)
      raise "Could not resolve #{self.table} in #{table_set}" unless table
      table.field_sql(fdef)
    end

    def summarisable?(field)
      return true if value_key?(field)
      fdef = self.field_def(field)
      fdef && fdef.summarisable?
    end

    def join_field
      'game_key_id'
    end

    def initialize(config, table, entity_name, alt_context, options)
      @config = config
      @table = table
      @entity_name = entity_name
      @alt = alt_context
      @game = GAME_TYPE_DEFAULT

      @noun_verb = { }
      @table_alias = options[:alias]
      @fields = options[:fields]
      @synthetic = options[:synthetic_fields]
      @defsort = Sql::Field.field(options[:default_sort])
      @raw_time_field = Sql::Field.field(options[:raw_time_field])
      @value_keys = options[:value_keys]
      @key_field  = Sql::Field.field(options[:key_field])
      @value_field = Sql::Field.field(options[:value_field])
    end

    def to_s
      "CTX[#{@table}]"
    end
  end
end
