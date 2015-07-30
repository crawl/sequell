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
      if @left_table.is_a?(Sql::QueryContext) || @right_table.is_a?(Sql::QueryContext)
        require 'pry'
        binding.pry
      end
      @left_fields = left_fields.map { |f| Sql::Field.field(f) }
      @right_fields = right_fields.map { |f| Sql::Field.field(f) }
      @join_mode = join_mode
      @join_mode_name = JOIN_MODES[@join_mode] or raise "Bad join mode: #{join_mode}"
    end

    def rebind_table(old_table, new_table)
      @left_table = new_table if @left_table == old_table
      @right_table = new_table if @right_table == old_table
      @left_fields.each { |f| rebind_field_table(f, old_table, new_table) }
      @right_fields.each { |f| rebind_field_table(f, old_table, new_table) }
    end

    def flip
      self.class.new(right_table, left_table, right_fields, join_mode, left_fields)
    end

    def flip!
      @left_table, @right_table = @right_table, @left_table
      @left_fields, @right_fields = @right_fields, @left_fields
      self
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
      return self if self == other || self.swap == other

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
        self.left_fields == other.left_fields &&
        self.right_fields == other.right_fields
    end

    def to_sql(include_left=false)
      join_sql_left = include_left ? left_table.to_sql + ' ' : ''
      join_base = "#{join_sql_left}#{join_mode_name} #{@right_table.to_sql} ON"
      join_base + ' ' + (0...@left_fields.size).map { |i|
        "#{@left_fields[i].to_sql} = #{@right_fields[i].to_sql}"
      }.join(' AND ')
    rescue
      STDERR.puts("Unable to sqlize join condition: #{self}")
      raise
    end

    def sql_values(include_left=false)
      if include_left
        left_table.sql_values + right_table.sql_values
      else
        right_table.sql_values
      end
    end

    def to_s
      "(#{field_join_conditions})"
    end

  private

    def field_join_conditions
      left_table_name = @left_table.to_s
      right_table_name = @right_table.to_s
      (0...left_fields.size).map { |i|
        "#{left_table_name}.#{left_fields[i].name}=#{right_table_name}.#{right_fields[i].name}]"
      }.join(' ')
    end

    def rebind_field_table(field, old_table, new_table)
      field.table = new_table if field.table == old_table
    end
  end
end
