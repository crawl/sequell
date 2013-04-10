module Tpl
  class Fragment
    attr_reader :fragments

    def initialize(*fragments)
      @fragments = fragments
    end

    def eval(expansion_provider)
      fragments.map { |f| f.eval(expansion_provider) }.join('')
    end

    def empty?
      false
    end

    def collapsible?
      true
    end

    def collapse
      args = []
      for fragment in fragments
        if fragment.collapsible?
          args += fragment.collapse.fragments
        else
          args << fragment unless fragment.empty?
        end
      end
      self.class.new(*args)
    end

    def to_s
      fragments.map(&:to_s).join('')
    end
  end
end
