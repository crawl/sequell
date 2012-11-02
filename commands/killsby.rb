#! /usr/bin/env ruby

$:.push('commands')
require 'helper'
require 'sqlhelper'
require 'query/query_string'

help("Lists the most frequent victims for a given monster. " +
     "Use -i to show indirect kills (e.g. rat summoned by vampire).")

args = (ARGV[2].split)[1 .. -1]

killer_field = args.include?('-i') ? 'ikiller' : 'ckiller'
args = args.select { |x| x != '-i' }

query = Query::QueryString.new("* #{killer_field}=" + args.join(' '))
report_grouped_games('name', '*', query.args)
