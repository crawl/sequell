module Cmd
  class UserDef
    attr_reader :name, :definition
    def initialize(name, definition)
      @name = name.to_s.downcase
      @definition = definition.to_s
    end

    def to_s
      "#{name} => #{definition}"
    end
  end
end
