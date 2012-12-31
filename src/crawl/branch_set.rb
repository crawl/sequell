require 'crawl/branch'

module Crawl
  class BranchSet
    def initialize(branches, place_fixups)
      @branches = branches.map { |br|
        Crawl::Branch.new(br)
      }
      @branch_map = Hash[ @branches.map { |br|
          [br.name.downcase, br]
        } ]
      @place_fixups = place_fixups
    end

    def [](name)
      @branch_map[name.downcase]
    end

    def deep?(name)
      branch_prop(name, :deep?)
    end

    # A branch that cannot make up its mind
    def deepish?(name)
      branch_prop(name, :deepish?)
    end

    def branch(keyword)
      keyword = @place_fixups.fixup(keyword)[0]
      if keyword =~ /^([a-z]+):/i
        self[$1]
      else
        self[keyword]
      end
    end

    def branch?(keyword)
      !!branch(keyword)
    end

  private
    def branch_prop(keyword, property)
      branch = self.branch(keyword)
      branch && branch.send(property)
    end
  end
end
