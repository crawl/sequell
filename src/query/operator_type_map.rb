require 'ostruct'

module Query
  class OperatorTypeMap
    def self.[](map, result)
      self.new(map, result)
    end

    attr_reader :result

    def initialize(map, default_result)
      @map = reify_types(map || '*')
      @result = Sql::Type.type(default_result || '*')
    end

    def polymorphic?
      @map.is_a?(Array)
    end

    def type
      @map
    end

    def coerce(arguments, arity)
      return arguments if !arguments || arguments.empty?
      if polymorphic?
        polymorphic_coerce(arguments, arity)
      else
        simple_coerce(arguments)
      end
    end

    def result_type(arguments)
      return self.result if !arguments || arguments.empty?
      argument_type = arguments.map(&:type).reduce(&:+)
      if polymorphic?
        matching_typemap(arguments).result.applied_to(argument_type)
      else
        result.applied_to(argument_type)
      end
    end

  private

    def simple_coerce(arguments)
      coerce_to = self.type.applied_to(arguments.first.type)
      arguments.each { |arg|
        arg.type.type_match?(coerce_to) or
          raise Sql::TypeError.new("Type mismatch: #{arg}")
        arg.convert_to_type(coerce_to)
      }
    end

    def matching_typemap(arguments)
      self.type.find { |t| type_match?(t, arguments) } or
        raise Sql::TypeError.new("Cannot apply to #{arguments}")
    end

    def type_match?(typemap, arguments)
      typemap.argtype.all? { |at|
        arguments.any? { |a| a.type.compatible?(at) }
      } &&
      arguments.all? { |a|
        typemap.argtype.any? { |t| t.compatible?(a.type) }
      }
    end

    def polymorphic_coerce(arguments, arity)
      typemap_coerce(matching_typemap(arguments), arguments)
    end

    def typemap_coerce(typemap, arguments)
      coercible = typemap.argtype.size == 1
      res = arguments.map { |a|
        if coercible
          a.convert_to_type(typemap.argtype.first)
        else
          a
        end
      }
      res
    end

    def reify_types(map)
      return Sql::Type.type(map) if map.is_a?(String)
      raise "Unexpected type map: #{map}" unless map.is_a?(Array)
      map.map { |mapping|
        reify_mapping(mapping)
      }
    end

    def reify_mapping(mapping)
      type = mapping['argtype']
      type = [type] unless type.is_a?(Array)
      OpenStruct.new(argtype: type.map { |t| Sql::Type.type(t) },
                     result: Sql::Type.type(mapping['result'] || '*'))
    end
  end
end
