module Cmd
  class UserDef
    attr_reader :name, :definition
    def initialize(name, definition)
      @name = name.downcase
      @definition = definition
    end

    def to_s
      "#{name} => #{definition}"
    end
  end
end
