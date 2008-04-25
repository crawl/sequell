#!/usr/bin/python

import sys
from helper import *

help("Lists the frequency of all character types a player started.")
  
games = games_for(sys.argv[1])
if len(games) == 0:
    print("No games for %s." % sys.argv[1])
    sys.exit()

types = []
uniq_types = []
for game in games:
    type = game['char']
    types.append(type)
    if type not in uniq_types:
        uniq_types.append(type)

uniq_types.sort(lambda x, y: cmp(types.count(y), types.count(x)) or cmp(x,y))
charstring = ''
for type in uniq_types:
    charstring += "%dx%s " % (types.count(type), type) 

print("%s has played %d games: %s" % (games[0]['name'], len(games), charstring))
