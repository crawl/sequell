require 'learndb'
require 'learndb_query'
require 'helper'

module Tpl
  FunctionDef.define('ldb-similar-terms', [1, 2]) {
    term = self[0].to_s
    distance = arity == 2 ? self[-1] : 2
    LearnDB::DB.default.candidate_terms(term, distance)
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
    Helper.raise_private_messaging!
    have_index = self.arity == 3
    LearnDB::DB.default.entry(self[0].to_s).add(self[-1], have_index ? self[-2].to_i : -1)
  }

  FunctionDef.define('ldb-rm!', 2) {
    Helper.raise_private_messaging!
    term_index = self[-1]
    term_index = nil if term_index.to_s == '*'
    LearnDB::DB.default.entry(self[0].to_s).delete(term_index)
  }

  FunctionDef.define('ldb-set!', 3) {
    Helper.raise_private_messaging!
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
