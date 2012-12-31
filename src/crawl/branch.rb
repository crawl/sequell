module Crawl
  class Branch
    def initialize(branch)
      @raw_branch = branch
      @branch = @raw_branch.sub(/(?::|\[:\])/, '')
      @deep = @raw_branch =~ /:/
      @deepish = @raw_branch =~ /\[:\]/
    end

    def deep?
      @deep
    end

    # A branch that cannot make up its mind whether it's deep or shallow.
    def deepish?
      @deepish
    end

    def name
      @branch
    end

    def to_s
      self.name
    end
  end
end
