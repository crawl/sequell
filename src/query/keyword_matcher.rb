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

    def lcarg
      arg.downcase
    end

    def context
      Sql::QueryContext.context
    end

    def match(context, keyword, expr)
      @context = context
      @keyword = keyword
      @expr = expr
      @value_field = nil
      self.parse
    end

    def value_field
      @value_field ||= Sql::Field.field(@keyword).bind_context(@context)
    end
  end
end
