require 'sql/field'
require 'sql/table_context'

module Sql
  class QueryContext
    include TableContext

    CONTEXT_MAP = { }
    @@global_context = nil

    def self.names
      CONTEXT_MAP.keys.sort
    end

    def self.named(name)
      name = name.to_s
      return self.context if name.empty?
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
    attr_accessor :alt
    attr_accessor :joined_tables

    alias :alias :table_alias

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
    #
    # If ignore_prefix is true, the context will ignore the field prefix and
    # always attempt to resolve the column.
    #
    def resolve_column(field, internal_expr, ignore_prefix=false)
      lookup_column(field, internal_expr, ignore_prefix, self, @alt)
    end

    ##
    # Looks up the field definition for the given field name String or
    # Sql::Field object in the local context, and returns a Sql::Column object
    # if found, or +nil+ if there is no column corresponding to the given field.
    #
    # This lookup will consider only fields local to this context. If you wish
    # to include auto-joined fields, use resolve_column instead.
    #
    # If ignore_prefix is true, the context will ignore the field prefix and
    # always attempt to resolve the column.
    #
    def resolve_local_column(field, internal_expr, ignore_prefix=false)
      field = Sql::Field.field(field)
      if ignore_prefix || !field.prefixed? || field.has_prefix?(@table_alias)
        col = @columns[field.name] || @synthetic_columns[field.name]
        col = col.bind(self) if col
      end
      col
    end

    ##
    # Returns true if the given context is the autojoin (alt) context for this
    # one.
    def autojoin?(context)
      @alt == context
    end

    ##
    #
    def bind_table_field(field)
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
    # Returns an array of fields that should be selected by default.
    def default_select_fields
      db_columns.map { |c| Sql::Field.field(c.name) }
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
      [self, @alt].each { |c|
        if c
          vkey = c.canonical_value_key(field)
          return vkey if vkey
        end
      }
      false
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

    ##
    # Returns the QueryTable for the primary table in this context.
    def query_table
      Sql::QueryTable.new(self.table)
    end

    # Given a field, returns a field that references this field in a
    # join table, if the field is a local field that is a reference type.
    def field_ref(field)
      local_column = self.resolve_local_column(field)
      return field unless local_column && local_column.reference?
      field.reference_field
    end

    ##
    # Returns the table this field belongs to.
    def field_origin_table(field)
      [self, @alt].each { |c|
        if c
          column = c.resolve_local_column(field, :internal_expr)
          return c.table if column
        end
      }
    end

    def table(game=GameContext.game)
      GAME_PREFIXES[game] + @table
    end

    def to_table_list_sql
      "#{table} AS #{self.alias}"
    end

    alias :to_sql :to_table_list_sql

    def db_column_expr(fdef, table_set)
      table = table_set.table(self.table)
      raise "Could not resolve #{self.table} in #{table_set}" unless table
      table.field_sql(fdef)
    end

    def join_field
      'game_key_id'
    end

    def key_field
      @key_field.dup if @key_field
    end

    def value_field
      @value_field.dup if @value_field
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

    def lookup_column(field, internal_expr, ignore_prefix, *contexts)
      return nil unless field
      field = Sql::Field.field(field)
      for ctx in contexts
        if ctx
          column = ctx.resolve_local_column(field, ignore_prefix)
          return column if column
        end
      end
      return nil
    end
  end
end
