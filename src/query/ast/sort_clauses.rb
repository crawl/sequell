module Query
  module AST
    class SortClauses
      include Enumerable

      def initialize(values=[])
        @values = values
      end

      def empty?
        @values.empty?
      end

      def each(&block)
        @values.each(&block)
      end

      def map(&block)
        SortClauses.new(@values.map(&block))
      end

      def join(s)
        @values.join(s)
      end

      def << (clause)
        @values << clause
      end

      def compact
        SortClauses.new(@values.compact)
      end

      def reverse_sorts!
        @values.map! { |sort|
          sort.reverse
        }
      end

      def to_s
        @values.map(&:to_s).join(' ')
      end
    end
  end
end
