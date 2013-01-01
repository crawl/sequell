#! /usr/bin/env ruby

require 'helper'
require 'sqlhelper'

help("Lists the most frequent causes of death for a player.")

args = ARGV[2].split()[1 .. -1]

report_grouped_games('ckiller', '', ARGV[1], args)
