#! /usr/bin/ruby

require 'commands/helper.rb'
require 'commands/sqlhelper.rb'

help("Lists the most frequent victims for a given monster or death type.")

args = (ARGV[2].split)[1 .. -1]

def killer_field(key)
  field = 'ckiller'
  "#{field}=#{key}"
end

args = sanitize_args(args)
killer = killer_field(args[0])

report_grouped_games('name', '', '*',
                     [ '*', killer ] + paren_args(args[1 .. -1]))
