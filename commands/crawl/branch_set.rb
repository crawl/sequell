require 'crawl/branch'

module Crawl
  class BranchSet
    def initialize(branches)
      @branches = branches.map { |br|
        Crawl::Branch.new(br)
      }
      @branch_map = Hash[ @branches.map { |br|
          [br.name.downcase, br]
        } ]
    end

    def [](name)
      @branch_map[name.downcase]
    end

    def deep?(name)
      branch = self[name]
      branch && branch.deep?
    end
  end
end
