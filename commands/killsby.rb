#! /usr/bin/ruby

require 'commands/helper.rb'
require 'commands/sqlhelper.rb'
require 'set'

help("Lists the top 10 player kills for a given monster.")

KTYP_FIELDS = [
               'pois', 'starvation', 'stupidity', 'water', 'burning',
               'draining', 'weakness', 'cloud', 'lava', 'clumsiness',
               'trap', 'freezing', 'wild_magic', 'statue', 'rotting',
               'targeting', 'spore', 'falling_down_stairs', 'petrification',
               'acid', 'curare', 'melting', 'bleeding', 'statue', 'xom',
               'tso_smiting', 'deaths_door'
               ]
KTYP_MAPPINGS = {
  "drown" => "water", "drowning" => 'water',
  'poison' => 'pois', 'poisoning' => 'pois'
}
KTYP_SET = Set.new(KTYP_FIELDS)

def killer_field(key)
  key = KTYP_MAPPINGS[key.downcase] || key
  if KTYP_SET.include?(key.downcase)
    "ktyp=#{key}"
  else
    "killer=#{key}"
  end
end

args = sanitize_args( (ARGV[2].split)[1 .. -1] )
killer = killer_field(args[0])

report_grouped_games('name', '', '*',
                     [ '*', killer ] + paren_args(args[1 .. -1]))
