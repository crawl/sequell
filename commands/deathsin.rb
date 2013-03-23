#! /usr/bin/env ruby

require 'sqlhelper'
require 'helper'
require 'query/query_string'

help("Lists the players who've died most frequently in a certain place.")

filters = Query::QueryString.new((ARGV[2].split)[1 .. -1])
query =
  Query::QueryString.new("* place=#{filters.first} " +
                         "ktyp!=quitting|leaving|winning")

filters.args = filters.args[1 .. -1]

report_grouped_games('name', '*', (query + filters).args)
