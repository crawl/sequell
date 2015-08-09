module Sql
  module TableContext
    ##
    # Returns the outer query that contains this query context, if any, or nil
    # otherwise.
    def outer_query
      nil
    end

    ##
    # Sets this context as the default (where relevant)
    def with(&block)
      not_implemented
    end

    ##
    # Formally registers a field belonging to this context as required. This
    # implies asking for the field's column to be SELECTed, and autojoining any
    # lookup table if necessary.
    def bind_table_field(field)
      not_implemented
    end

    ##
    # Returns the full/long name of this context. For instance, this might be
    # the full table name "logrecord", as opposed to the alias "lg".
    #
    # The name is not guaranteed to be an identifier: it may be a representation
    # of the query for subqueries. This method is only informational.
    def name
      not_implemented
    end

    ##
    # Returns the short alias of this context. For instance, this
    # might be "lg" for the "logrecord" context.
    #
    # The alias MUST be a valid SQL identifier.
    def alias
      not_implemented
    end

    ##
    # Returns the SQL table for the given game in this context.
    def table(game)
      not_implemented
    end

    ##
    # Look up the Sql::Column for the given field, checking
    # autojoin contexts if available.
    #
    # If internal_expr is true, the column being resolved is
    # a direct reference to the context from a local query on
    # the context: for instance, it is a select or where clause
    # reference to the table (context) being queried.
    #
    # If internal_expr is false, the column being resolved is
    # an external reference from an outer query to a field in
    # this context.
    #
    # If this table context represents a subquery, it may
    # handle internal_expr differently from !internal_expr.
    def resolve_column(field, internal_expr)
      not_implemented
    end

    ##
    # Look up the Sql::Column for the given field, checking
    # only this context and ignoring autojoin contexts.
    #
    # If internal_expr is true, the column being resolved is
    # a direct reference to the context from a local query on
    # the context: for instance, it is a select or where clause
    # reference to the table (context) being queried.
    #
    # If internal_expr is false, the column being resolved is
    # an external reference from an outer query to a field in
    # this context.
    #
    # If this table context represents a subquery, it may
    # handle internal_expr differently from !internal_expr.
    def resolve_local_column(field, internal_expr)
      not_implemented
    end

    ##
    # Returns true if this field is really a special value
    # that implies a simple expression transform.
    #
    # Concretely, in conditions such as rune=silver,
    # value_key?('rune') == true, and implies an expression
    # of "type=rune noun=silver".
    def value_key?(field)
      not_implemented
    end

    ##
    # Given a milestone value, canonicalizes it.
    def canonical_value_key(value)
      not_implemented
    end

    ##
    # Returns the default value field for the value_key? transform.
    # For milestones, always returns noun.
    def value_field
      not_implemented
    end

    ##
    # Returns true if the other context is one of the autojoining
    # contexts for this table. An autojoining context is one where
    # references to fields automatically imply a standard join.
    def autojoin?(context)
      not_implemented
    end

    ##
    # Returns a list of tables, possibly joined to other tables and subqueries,
    # suitable for use in a SQL FROM clause.
    def to_table_list_sql
      not_implemented
    end

    ##
    # Returns the table that the given field belongs to.
    def field_origin_table(field)
      not_implemented
    end

    ##
    # Returns the field used to select the key: for milestones, this is the
    # "type" or "verb" field.
    def key_field
      not_implemented
    end

    ##
    # Returns the field used to select the value: for milestones this is the
    # "noun" field.
    def value_field
      not_implemented
    end

  private

    def not_implemented
      raise("Not implemented #{self.class}")
    end
  end
end
