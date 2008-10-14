#! /usr/bin/ruby

require 'commands/helper.rb'
require 'commands/sqlhelper.rb'

help("Lists the most frequent victims for a given monster.")

def killer_field(key)
  "ckiller=#{key}"
end

args = sanitize_args( (ARGV[2].split)[1 .. -1] )
killer = killer_field(args[0])

report_grouped_games('name', '', '*',
                     [ '*', killer ] + paren_args(args[1 .. -1]))
