module Query
  module AST
    class KeyedOptionList < Term
      def initialize(*options)
        self.arguments = options
      end

      def meta?
        true
      end

      def kind
        :keyed_option_list
      end

      def merge!(other)
        self.arguments = (self.arguments + other.arguments).uniq
      end

      def arguments=(opts)
        @arguments = opts
        @option_map = Hash[
          @arguments.map { |arg| [arg.name, arg.value] }
        ]
        @arguments
      end

      def <<(opt)
        @option_map[opt.name] = opt.value
        @arguments << opt
      end

      def [](name)
        @option_map[name.to_s]
      end

      def option(name)
        self[name]
      end

      def to_s
        "-opt:(" + arguments.map(&:to_s).join(", ") + ")"
      end
    end
  end
end
