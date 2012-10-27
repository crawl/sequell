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
    attr_accessor :fields, :synthetic, :summarisable, :defsort
    attr_accessor :noun_verb, :noun_verb_fields
    attr_accessor :fieldmap, :synthmap, :table_alias
    attr_reader   :raw_time_field
    attr_reader   :key_field, :value_field

    def with
      old_context = @@global_context
      begin
        @@global_context = self
        yield
      ensure
        @@global_context = old_context
      end
    end

    def db_field_names
      @fields.columns.map { |column_def|
        db_column_expr(column_def)
      }
    end

    def field?(field)
      self.field_def(field) || self.value_key?(field)
    end

    def value_key?(field)
      @value_keys && field === @value_keys
    end

    def local_field_def(field)
      (!field.prefixed? || field.has_prefix?(@table_alias)) &&
        (@fields[field.name] || @synthetic[field.name])
    end

    def field_def(field)
      if field.prefixed?
        if field.has_prefix?(@table_alias)
          @fields[field.name] || @synthetic[field.name]
        else
          @alt && @alt.field_type(field)
        end
      else
        @fields[field.name] || @synthetic[field.name] ||
          (@alt && @alt.field(field))
      end
    end

    def field_type(field)
      field_definition = self.field_def(field)
      field_definition && field_definition.type
    end

    def table
      GAME_PREFIXES[GameContext.game] + @table
    end

    def dbfield(field)
      local_fdef = self.local_field_def(field)
      if local_fdef
        self.db_column_expr(local_fdef)
      elsif @alt
        @alt.dbfield(field)
      else
        raise "Unknown field: #{field}"
      end
    end

    def db_column_expr(fdef)
      "#{@table_alias}.#{fdef.sql_column_name}"
    end

    def summarise?(field)
      fdef = self.field_def(field)
      fdef.summarisable?
    end

    def initialize(config, table, entity_name, alt_context,
                   options)
      @config = config
      @table = table
      @entity_name = entity_name
      @alt = alt_context
      @game = GAME_TYPE_DEFAULT

      if @table =~ / (\w+)$/
        @table_alias = $1
      else
        @table_alias = @table
      end

      @noun_verb = { }
      @fields = options[:fields]
      @synthetic = options[:synthetic_fields]
      @defsort = Sql::Field.field_named(options[:default_sort])
      @raw_time_field = Sql::Field.field_named(options[:raw_time_field])
      @value_keys = options[:value_keys]
      @key_field  = Sql::Field.field_named(options[:key_field])
      @value_field = Sql::Field.field_named(options[:value_field])
    end
  end
end
