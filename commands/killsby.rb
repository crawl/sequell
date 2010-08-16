#! /usr/bin/ruby

require 'commands/helper.rb'
require 'commands/sqlhelper.rb'

help("Lists the most frequent victims for a given monster. " +
     "Use -i to show indirect kills (e.g. rat summoned by vampire).")

args = (ARGV[2].split)[1 .. -1]

$ikiller = args.include?('-i')
args = args.select { |x| x != '-i' }

def killer_field(key)
  field = $ikiller ? 'ikiller' : 'ckiller'
  "#{field}=#{key}"
end

game = extract_game_type(arg)
args = sanitize_args(args)
killer = killer_field(args[0])

report_grouped_games('name', '', '*',
                     [ '*', game, killer ] + paren_args(args[1 .. -1]))
