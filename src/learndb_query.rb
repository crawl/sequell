require 'tpl/template'
require 'cmd/executor'

class LearnDBQuery
  def self.redirect_pattern
    /^\s*see\s+\{(.*)\}\s*$/i
  end

  def self.query(db, scope, query, index=nil, fuzzy=true)
    if index.nil?
      query, index = self.parse_query(query)
    end

    self.new(db, scope, query, index, { }, fuzzy).query
  end

  def self.lookup_string(query, index=nil)
    return query if index.nil? || index == 1
    "#{query}[#{index}]"
  end

  def self.resolve_redirect_terms(db, query)
    query, index = self.parse_query(query)
    seen = Set.new([query.downcase.strip])
    while true
      redir = self.redirect_term?(db, query)
      break unless redir

      redir_term, _ = self.parse_query(redir)
      redir_term = redir_term.downcase.strip
      query = redir_term
      break if seen.include?(redir_term)
      seen << redir_term
    end
    self.lookup_string(db.real_term(query), index)
  end

  def self.redirect_term?(db, query)
    query, _ = self.parse_query(query)
    e = db.entry(query)
    return false if e.size != 1
    redir = redirect_entry?(e[1].text)
    return false unless redir
    pattern = redir[1]
    return false if pattern =~ /\[\s*([+-]?\d+|\$)\s*\]?$/ && $1 != '1'
    pattern
  end

  def self.redirect_entry?(entry_text)
    redirect_pattern.match(entry_text.to_s)
  end

  def self.parse_query(query)
    if query =~ /^(.*)\[([+-]?\d+|\$)\]?\s*$/
      [$1, $2 == '$' ? -1 : $2.to_i]
    else
      [query, 1]
    end
  end

  attr_reader :db, :scope, :term, :original_term, :index, :visited
  def initialize(db, scope, term, index, visited, fuzzy=true)
    @db = db
    @scope = scope
    @term = term
    @original_term = term
    @index = index
    @visited = visited
    @fuzzy = fuzzy
  end

  def visited?(term, index=1)
    visited[key(term, index)]
  end

  def key(term, index)
    "#{term}||#{index}"
  end

  def mark_visited!(term, index)
    visited[key(term, index)] = true
  end

  def fuzzy?
    @fuzzy
  end

  def query
    mark_visited!(term, index)

    entry = @db.entry(term)
    if !entry.exists? && fuzzy?
      candidates = @db.candidate_terms(term)
      if candidates.size == 1
        @term = candidates[0]
        entry = @db.entry(candidates[0])
      end
    end
    lookup = entry[index]

    if index == -1 || (!lookup && index != 1)
      result = full_entry_redirect(entry)
      return with_query_path(result) if result || index != -1
    end

    with_query_path(resolve(lookup)) if lookup
  end

  def with_query_path(result)
    return result unless result
    result.original_term = original_term
    result.term = term
    result
  end

  ##
  # Given a term A that redirects to another term B as its first
  # entry, A[x] should behave the same as B[x] for queries. This function
  # attempts to follow the redirect as term(A[1])[x] if A[x] returns nothing.
  def full_entry_redirect(entry)
    first_item = entry[1]
    return nil unless first_item
    match = redirect?(first_item)
    return nil unless match
    pattern = match[1]
    new_term, new_index = self.class.parse_query(pattern)
    return nil if new_index != 1
    follow_redirect(new_term, index)
  end

  def follow_redirect(new_term, new_index)
    return nil if visited?(new_term, new_index)
    self.class.new(db, scope, new_term, new_index, visited).query
  end

  def redirect?(result)
    self.class.redirect_entry?(result.text)
  end

  def resolve(result)
    if redirect?(result)
      result = resolve_redirect(result)
    end

    command = redirect_pattern(result)
    if command
      command_res = command_eval(result, command)
      return command_res if command_res
    end

    if result.text =~ /^\s*do\s+\{(.*)\}\s*$/i
      command_res = command_eval(result, $1)
      return command_res if command_res
    end

    res = scope ? Tpl::Template.template_eval(result.text, scope) : result.text
    LearnDB::LookupResult.new(result.entry, result.index, result.size, res)
  end

  def command_eval(result, command)
    LearnDB::LookupResult.new(result.entry, result.index, result.size,
      Tpl::Template.subcommand_eval(command, scope), true)
  rescue Cmd::UnknownCommandError
    nil
  end

  def redirect_pattern(result)
    match = redirect?(result)
    match && match[1]
  end

  def resolve_redirect(result)
    visited ||= { }
    pattern = redirect_pattern(result)
    return result unless pattern
    new_term, new_index = self.class.parse_query(pattern)
    follow_redirect(new_term, new_index) || result
  end
end
