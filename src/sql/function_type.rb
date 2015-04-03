module Sql
  class FunctionType
    def initialize(arg_type, return_type)
      @types = normalize(arg_type, return_type)
    end

    def type_match(args)
      @types.find { |t|
        t.type.size == args.size && types_match(t.type, args)
      } or raise Sql::TypeError.new("Cannot apply to #{args} (want #{@types})")
    end

    def return_type(args)
      first_arg_type = args && args.first && args.first.type
      type_match(args).return.applied_to(first_arg_type)
    end

    def coerce_argument_types(args)
      coerce_typematch(type_match(args), args)
    end

  private

    def coerce_typematch(type, args)
      arg_types = type.type
      (0...arg_types.size).map { |i|
        args[i].convert_to_type(arg_types[i])
      }
    end

    def types_match(types, args)
      (0...types.size).all? { |i|
        types[i].compatible?(args[i].type)
      }
    end

    def normalize(arg_type, return_type)
      unless arg_type.is_a?(Array)
        arg_type = [{ 'type' => arg_type, 'return' => (return_type || '*') }]
      end

      arg_type.map { |at|
        OpenStruct.new(type: normalize_argtypes(at['type']),
                       return: Sql::Type.type(at['return'] || '*'))
      }
    end

    def normalize_argtypes(argtype)
      argtype = [argtype] unless argtype.is_a?(Array)
      argtype.map { |a| Sql::Type.type(a) }
    end
  end
end
