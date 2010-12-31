#! /usr/bin/env ruby

require 'commands/helper.rb'
require 'commands/sqlhelper.rb'

help("Lists the top kills for a player's ghost.")

args = (ARGV[2].split)[1 .. -1] || []

ghosts = nick_aliases( extract_nick(args) || ARGV[1] )

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

report_grouped_games('name', '', '*', [ '*' ] + fields + paren_args(args))
