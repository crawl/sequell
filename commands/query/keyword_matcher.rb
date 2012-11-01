module Query
  class KeywordMatcher
    @@matchers = []

    def self.matcher(name, &block)
      matcher = self.new(name, block)
      @@matchers << matcher
    end

    def self.each(&block)
      @@matchers.each(&block)
    end

    attr_reader :name, :keyword, :expr

    alias :arg :keyword
    alias :value :keyword

    def initialize(name, block)
      @name = name
      cls = (class << self; self; end)
      cls.send(:define_method, :parse, &block)
    end

    def match(keyword, expr)
      @keyword = keyword
      @expr = expr
      self.parse
    end
  end
end
