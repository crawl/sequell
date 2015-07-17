require 'sql/field'

module Sql
  class QueryContext
    CONTEXT_MAP = { }
    @@global_context = nil

    def self.names
      CONTEXT_MAP.keys.sort
    end

    def self.named(name)
      name = name.to_s
      return nil if name.empty?
      CONTEXT_MAP[name] || self.context
    end

    def self.register(name, context)
      CONTEXT_MAP[name] = context
      CONTEXT_MAP[name.gsub('!', '')] = context
    end

    def self.context
      @@global_context
    end

    def self.context=(ctx)
      @@global_context = ctx
    end

    attr_reader   :config
    attr_accessor :entity_name, :name
    attr_accessor :fields, :synthetic, :defsort
    attr_accessor :table_alias
    attr_reader   :time_field
    attr_reader   :alt
    attr_accessor :joined_tables

    def with
      old_context = @@global_context
      begin
        @@global_context = self
        yield
      ensure
        @@global_context = old_context
      end
    end

    ##
    # Returns a copy of this context modified to look up the
    # joined tables in addition to the context's fields.
    def with_joined_tables(joined_tables)
      clone = self.dup
      clone.joined_tables = joined_tables
      clone
    end

    ##
    # Returns true if the given name is a table alias for this context
    # or its alt.
    def table_alias?(name)
      name == self.table_alias || (alt && name == alt.table_alias)
    end

    ##
    # Looks up the field definition for the given field name String or
    # Sql::Field object and returns a Sql::Column object if found, or +nil+ if
    # there is no column corresponding to the given field.
    #
    # The resolve_column lookup will consider both fields local to this context
    # and any auto-join fields. If you wish to ignore auto-joined fields, use
    # resolve_local_column
    def resolve_column(field)
      lookup_column(field, self, @alt)
    end

    ##
    # Looks up the field definition for the given field name String or
    # Sql::Field object in the local context, and returns a Sql::Column object
    # if found, or +nil+ if there is no column corresponding to the given field.
    #
    # This lookup will consider only fields local to this context. If you wish
    # to include auto-joined fields, use resolve_column instead.
    def resolve_local_column(field)
      field = Sql::Field.field(field)
      (!field.prefixed? || field.has_prefix?(@table_alias)) &&
        (@columns[field.name] || @synthetic_columns[field.name])
    end

    ##
    # Returns a list of all local db columns in this query context. This does not
    # include auto-joined columns.
    #
    # The return value is an Array of Sql::Column objects.
    def db_columns
      @columns.columns
    end

    ##
    # Returns +true+ if the given field name represents a real or synthetic
    # field in this context
    def field?(field)
      self.resolve_column(field) || self.value_key?(field)
    end

    ##
    # Returns +true+ if the given name is really a known field value for a field
    # such as a milestone type. This is used to decide when to rewrite
    # expressions such as rune=barnacled.
    def value_key?(field)
      self.canonical_value_key(field)
    end

    ##
    # Returns true if the function name is a real function in this context.
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

    # Given a field, returns a field that references this field in a
    # join table, if the field is a local field that is a reference type.
    def field_ref(field)
      local_column = self.local_column_def(field)
      return field unless local_column && local_column.reference?
      field.reference_field
    end

    def table_qualified(field)
      fdef = self.local_column_def(field)
      if fdef
        clone = field.dup
        clone.table = Sql::QueryTable.new(self.table)
        return clone
      elsif @alt
        return @alt.table_qualified(field)
      end
      field
    end

    def table(game=GameContext.game)
      GAME_PREFIXES[game] + @table
    end

    def db_column_expr(fdef, table_set)
      table = table_set.table(self.table)
      raise "Could not resolve #{self.table} in #{table_set}" unless table
      table.field_sql(fdef)
    end

    def join_field
      'game_key_id'
    end

    def key_field
      @key_field.dup
    end

    def value_field
      @value_field.dup
    end

    def initialize(config, name, table, entity_name, alt_context, options)
      self.class.register(name, self)
      @name = name
      @config = config
      @table = table
      @entity_name = entity_name
      @alt = alt_context
      @game = GAME_TYPE_DEFAULT

      @noun_verb = { }
      @table_alias = options[:alias]
      @columns = options[:columns]
      @synthetic_columns = options[:synthetic_columns]
      @defsort = Sql::Field.field(options[:default_sort])
      @time_field = Sql::Field.field(options[:time_field])
      @value_keys = options[:value_keys]
      @key_field  = Sql::Field.field(options[:key_field])
      @value_field = Sql::Field.field(options[:value_field])
    end

    def milestone?
      @entity_name == 'milestone'
    end

    def to_s
      "CTX[#{@table}]"
    end

    def inspect
      to_s
    end

  private

    def lookup_column(field, *contexts)
      return nil unless field
      field = Sql::Field.field(field)
      for ctx in contexts
        if ctx
          column = ctx.local_column_def(field)
          return column if column
        end
      end
      return nil
    end
  end
end
