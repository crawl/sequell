require 'learndb'
require 'learndb_query'
require 'helper'

module Tpl
  FunctionDef.define('ldb-similar-terms', 1) {
    term = self[0].to_s
    LearnDB::DB.default.candidate_terms(term)
  }

  FunctionDef.define('ldb-lookup', 1) {
    term = self[0].to_s
    LearnDBQuery.query(LearnDB::DB.default, scope, term)
  }

  FunctionDef.define('ldb', [1, 2]) {
    term = self[0].to_s
    index = arity == 2 ? self[-1].to_i : 1
    LearnDBQuery.query(LearnDB::DB.default, scope, term, index)
  }

  FunctionDef.define('ldb-redirect-term?', 1) {
    LearnDBQuery.redirect_term?(LearnDB::DB.default, self[0].to_s)
  }

  FunctionDef.define('ldb-canonical-term', 1) {
    LearnDBQuery.resolve_redirect_terms(LearnDB::DB.default, self[0].to_s)
  }

  FunctionDef.define('ldb-search-terms', 1) {
    search = self[0]
    search = RE2::Regexp.new(search.to_s) unless search.is_a?(RE2::Regexp)
    LearnDB::DB.default.terms_matching(search)
  }

  FunctionDef.define('ldb-search-entries', 1) {
    search = self[0]
    search = RE2::Regexp.new(search.to_s) unless search.is_a?(RE2::Regexp)
    LearnDB::DB.default.entries_matching(search)
  }

  FunctionDef.define('ldb-at', [1, 2]) {
    term = self[0].to_s
    index = arity == 2 ? self[-1].to_i : 1
    LearnDB::DB.default.entry(term)[index]
  }

  FunctionDef.define('ldb-defs', 1) {
    term = self[0].to_s
    LearnDB::DB.default.entry(term).definitions
  }

  FunctionDef.define('ldb-size', 1) {
    LearnDB::DB.default.entry(self[0].to_s).size
  }

  FunctionDef.define('ldb-add', [2, 3]) {
    db = LearnDB::DB.default
    term = self[0].to_s
    IrcAuth.authorize!('db:' + db.canonical_term(term).downcase)
    have_index = self.arity == 3
    db.entry(term).add(self[-1], have_index ? self[-2].to_i : -1)
  }

  FunctionDef.define('ldb-rm!', 2) {
    db = LearnDB::DB.default
    term = self[0].to_s
    IrcAuth.authorize!('db:' + db.canonical_term(term).downcase)
    begin
      term_index = self[-1]
      term_index = nil if term_index.to_s == '*'
      db.entry(term).delete(term_index)
    rescue LearnDB::EntryIndexError
      nil
    end
  }

  FunctionDef.define('ldb-set!', 3) {
    db = LearnDB::DB.default
    term = self[0].to_s
    IrcAuth.authorize!('db:' + db.canonical_term(term).downcase)
    begin
      LearnDB::DB.default.entry(self[0].to_s)[self[1].to_i] = self[2].to_s
    rescue LearnDB::EntryIndexError
      nil
    end
  }

  FunctionDef.define('ldbent-term', 1) {
    e = self[0]
    e.nil? ? '' : e.entry.name
  }
  FunctionDef.define('ldbent-index', 1) {
    e = self[0]
    e.nil? ? 0 : e.index
  }
  FunctionDef.define('ldbent-term-size', 1) {
    e = self[0]
    e.nil? ? 0 : e.entry.size
  }
  FunctionDef.define('ldbent-text', 1) {
    e = self[0]
    e.nil? ? '' : e.text
  }
end
