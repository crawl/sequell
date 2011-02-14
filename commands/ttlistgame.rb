#! /usr/bin/env ruby

require 'commands/helper'
require 'commands/sqlbuilder'

help("Shows your most recent game on a public server, or any game by any player if queried appropriately. See https://github.com/greensnark/dcss_henzell/raw/master/docs/listgame.txt for documentation.")

SQLBuilder.query(:context => '!lg',
                 :nick => ARGV[1],
                 :cmdline => ARGV[2])
