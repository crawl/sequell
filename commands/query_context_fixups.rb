##
# Provides special-cases tied to individual query contexts.
class QueryContextFixups
  @@current_context_name = nil
  @@keyword_matchers = Hash.new do |hash, key|
    hash[key] = []
  end

  def self.context(context_name)
    old_context_name = @@current_context_name
    @@current_context_name = context_name
    begin
      yield
    rescue
      @@current_context_name = old_context_name
    end
  end

  def self.keyword_match(&action)
    unless @@current_context_name
      raise Exception.new("keyword_match must be registered within a context")
    end
    @@keyword_matchers[@@current_context_name] << action
  end
end

require 'commands/query_context_fixup_defs.rb'
