require 'learndb'
require 'learndb_query'
require 're2'

module Services
  module LearnDB
    class NotFound < StandardError
      def initialize(query)
        super(query)
      end
      def to_s
        "Not Found: #{super}"
      end
    end

    class Search
      attr_reader :query

      def initialize(query)
        @query = query
        @re = RE2::Regexp.new(@query.to_s)
      end

      def db
        @db ||= ::LearnDB::DB.default
      end

      def terms
        @terms ||= db.terms_matching(@re)
      end

      def entries
        @entries ||= db.entries_matching(@re)
      end

      def result_json
        {
          terms: self.terms,
          entries: entries.map { |e| entry_json(e) }
        }
      end

      private

      def entry_json(r)
        {
          term: r.entry,
          index: r.index,
          text: r.text
        }
      end
    end

    class Lookup
      attr_reader :term

      def initialize(term)
        @term = term
      end

      def result_json
        result = LearnDBQuery.query(::LearnDB::DB.default, nil, term.to_s)
        raise NotFound.new(term.to_s) unless result
        {
          term: result.entry.name,
          originalLookup: term,
          definitions: result.entry.definitions,
          chosenIndex: result.index
        }
      end
    end
  end
end
