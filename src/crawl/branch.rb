module Crawl
  class Branch
    def initialize(branch)
      @raw_branch = branch
      @branch = @raw_branch.sub(':', '')
      @deep = @raw_branch =~ /:/
    end

    def deep?
      @deep
    end

    def name
      @branch
    end

    def to_s
      self.name
    end
  end
end
