module Query
  module AST
    class KeyedOption < Term
      KEY_ALIASES = {
        'sfmt' => 'fmt',
        'summary_format' => 'fmt',
        'format' => 'fmt',
        'parent_format' => 'pfmt'
      }

      attr_accessor :name, :value

      def initialize(name, value)
        @name = KEY_ALIASES[name] || name
        @value = value
      end

      def kind
        :keyed_option
      end

      def meta?
        true
      end

      def quoted_value
        '"' + value.gsub(/([\\"])/, '\\\1') + '"'
      end

      def == (other)
        unless other.respond_to?(:name) && other.respond_to?(:value)
          return false
        end
        self.name == other.name && self.value == other.value
      end

      def to_s
        "#{name}:#{quoted_value}"
      end
    end
  end
end
