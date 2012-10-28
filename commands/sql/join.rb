require 'sql/field'

module Sql
  class Join
    attr_reader :left_table, :right_table, :left_field, :right_field

    def initialize(left_table, right_table, left_field,
                   right_field=Sql::Field.new('id'))
      @left_table = Sql::QueryTable.table(left_table)
      @right_table = Sql::QueryTable.table(right_table)
      @left_field = Sql::Field.field(left_field)
      @right_field = Sql::Field.field(right_field)
    end

    def == (other)
      self.left_table.name == other.left_table.name &&
        self.right_table.name == other.right_table.name &&
        self.left_field.name == other.left_field.name &&
        self.right_field.name == other.right_field.name
    end

    def to_sql
      "INNER JOIN #{@right_table.to_sql} ON " +
        "#{@left_table.field_sql(@left_field)} = " +
        "#{@right_table.field_sql(@right_field)}"
    end

    def to_s
      "Join[#{@left_table.name}.#{@left_field.name}=#{@right_table.name}.#{@right_field.name}]"
    end
  end
end
