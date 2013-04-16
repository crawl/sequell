module Tpl
  class Binding
    attr_accessor :name, :value

    def initialize(name, value)
      @name = name
      @value = value
    end

    def to_s
      "#{@name} #{@value}"
    end
  end
end
