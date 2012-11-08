require 'learndb'

module Henzell
  class LearnDBQuery
    INDEX_RE = /\[([+-]?\d+|random|any)\]$/
    def self.query(term)
      self.new(term).query
    end

    def initialize(term)
      @index = 0
      @random = false
      if term =~ INDEX_RE
        term_set_index($1)
        term = term.sub(INDEX_RE, '').strip
      end
      @term = term
      @entry = LearnDB.entry(@term)
    end

    def random?
      @random
    end

    def query
      size = @entry.size
      return '' if size == 0
      chosen_index = self.choose_index(size)
      "#{chosen_index + 1}/#{size}. #{entry(chosen_index)}"
    end

    def choose_index(size)
      if random?
        rand(size)
      else
        @index % size
      end
    end

    def entry(index)
      @entry[index]
    end

  private
    def term_set_index(index)
      if index == 'random' || index == 'any'
        @index = :any
        @random = true
        return
      end
      @index = index.to_i
      @index -= 1 if @index > 0
    end
  end
end
