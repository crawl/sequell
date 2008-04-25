#!/usr/bin/python

import sys
from helper import *

help("Lists a player's last game.")

nick = sys.argv[1]

games = games_for(nick)

if not games:
  print("No games for %s." % nick)
  sys.exit()

print('\n%s. :%s:' % (len(games), str(munge_game(games[-1]))))
