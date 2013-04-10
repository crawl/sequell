module Tpl
  class Fragment
    attr_reader :fragments

    def initialize(*fragments)
      @fragments = fragments
    end

    def eval(expansion_provider)
      fragments.map { |f| f.eval(expansion_provider) }.join('')
    end

    def collapse
      args = []
      for fragment in fragments
        if fragment.is_a?(Fragment)
          args += fragment.collapse.fragments
        else
          args << fragment
        end
      end
      self.class.new(*args)
    end

    def to_s
      "Fragment[" + fragments.map(&:to_s).join(', ') + "]"
    end
  end
end
