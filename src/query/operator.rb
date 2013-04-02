module Query
  class Operator
    REGISTRY = { }

    def self.op(name)
      REGISTRY[name.to_sym] || raise "No operator: #{name}"
    end

    def self.define(name, options)
      self.new(name, options)
    end

    def self.register(name, op)
      REGISTRY[name] = op
    end

    def initialize(name, options)
      @name = name
      @options = options
      self.class.register(name, self)
    end

    def argtypes
      @argtypes ||=
        (if @options[:argtype].is_a?(Array)
           @options[:argtype]
         elsif @options[:argtype]
           [@options[:argtype]]
         end).map { |type| Sql::Type.type(type) }
    end

    def typecheck!(args)
      !self.argtypes ||
      self.argtypes.any { |argtype|
        args.all? { |arg|
          arg.type.type_match?(argtype)
        }
      }
    end

    def result_type(args)
      @options[:result] || args.first.type
    end
  end
end
