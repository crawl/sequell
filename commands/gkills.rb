#! /usr/bin/env ruby

$:.push("src")
require 'helper'
require 'sqlhelper'
require 'query/query_string'
require 'query/nick_resolver'
require 'query/nick'

help("Lists the top kills for a player's ghost.")

args = (ARGV[2].split)[1 .. -1] || []

query = Query::QueryString.new(args)
nick = Query::NickResolver.extract_nick(query) || ARGV[1]
ghosts = Query::Nick.aliases(nick)

def ghost_field(ghost)
  if ghost == '*'
    "killer=~*'*ghost"
  else
    "killer=~#{ghost}'*ghost"
  end
end

fields = [ ]
if ghosts.size == 1
  fields << ghost_field(ghosts[0])
else
  ghosts = ghosts.map { |g| Regexp.quote(g) }
  fields << "killer~~^(#{ghosts.join("|")})'.*ghost"
end

report_grouped_games('name', '*', [ '*' ] + fields + paren_args(query.args))
