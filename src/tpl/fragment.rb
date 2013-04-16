require 'tpl/tplike'

module Tpl
  class Fragment
    include Tplike

    def self.identifier(fragment)
      return fragment unless fragment.respond_to?(:identifier)
      fragment.identifier
    end

    attr_reader :fragments

    def initialize(*fragments)
      @fragments = fragments.map { |frag|
        !frag.is_a?(Tplike) ? TextFragment.new(frag) : frag
      }
    end

    def [](index)
      @fragments[index]
    end

    def eval(expansion_provider)
      fragments.map { |f| string(f.eval(expansion_provider)) }.join('')
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
        fragment = fragment.collapse if fragment.collapsible?
        if fragment.collapsible?
          args += fragment.fragments
        elsif !fragment.empty?
          if fragment.is_a?(TextFragment) && !args.empty? &&
              args[-1].is_a?(TextFragment)
            args[-1].text += fragment.text
          else
            args << fragment
          end
        end
      end
      if args.size == 1
        args.first
      else
        self.class.new(*args)
      end
    end

    def to_s
      fragments.map(&:to_s).join('')
    end
  end
end
