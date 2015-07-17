require 'sql/field'

module Sql
  class Join
    attr_reader :left_table, :right_table, :left_fields, :right_fields
    attr_reader :join_mode, :join_mode_name

    JOIN_MODES = {
      left: 'LEFT JOIN',
      inner: 'JOIN',
      right: 'RIGHT JOIN'
    }

    ##
    # Creates a Join object that joins two tables, with a specified +join_mode+,
    # joining the given left and right fields on equality.
    #
    # join_mode must be one of :left, :right, or :inner.
    #
    # The table objects must respond to :to_sql and field_sql(x), where x is a
    # Sql::Field object.
    def initialize(left_table, right_table,
                   left_fields,
                   join_mode=:inner,
                   right_fields=['id'])
      @left_table = Sql::QueryTable.table(left_table)
      @right_table = Sql::QueryTable.table(right_table)
      @left_fields = left_fields.map { |f| Sql::Field.field(f) }
      @right_fields = right_fields.map { |f| Sql::Field.field(f) }
      @join_mode = join_mode
      @join_mode_name = JOIN_MODES[@join_mode] or raise "Bad join mode: #{join_mode}"
    end

    ##
    # Returns true if this join's tables exactly match the other join's tables.
    def tables_match?(other)
      (left_table == other.left_table && right_table == other.right_table) ||
        (left_table == other.right_table && right_table == other.left_table)
    end

    ##
    # Merge the other's join conditions into our own.
    def merge!(other)
      raise "Incompatible join condition!" unless tables_match?(other)

      # Direct match
      if left_table == other.left_table
        @left_fields += other.left_fields
        @right_fields += other.right_fields
      else # Cross-match:
        @left_fields += other.right_fields
        @right_fields += other.left_fields
      end
      self
    end

    def left_join?
      @join_mode == :left
    end

    def == (other)
      self.left_table.name == other.left_table.name &&
        self.right_table.name == other.right_table.name &&
        self.left_field.name == other.left_field.name &&
        self.right_field.name == other.right_field.name
    end

    def to_sql(include_left=false)
      join_sql_left = include_left ? left_table.to_sql + ' ' : ''
      join_base = "#{join_sql_left}#{join_mode_name} #{@right_table.to_sql} ON"
      join_base + ' ' + (0...@left_fields.size).map { |i|
        "#{@left_table.field_sql(@left_fields[i])} = " +
        "#{@right_table.field_sql(@right_fields[i])}"
      }.join(' AND ')
    end

    def to_s
      "Join[#{@left_table.name}.#{@left_field.name}=#{@right_table.name}.#{@right_field.name}]"
    end
  end
end
