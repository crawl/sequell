#!/usr/bin/python

import sys
from helper import *

help("Lists a player's lowest scoring win.")

games = games_for(sys.argv[1])

if not games:
    print('No games for %s.' % sys.argv[1])
    sys.exit()
lsa = (games[0], 0)
wins = 0
for game in games:
    if game['ktyp'] == 'winning':
        wins += 1
        if lsa[0]['ktyp'] != 'winning':
            lsa = (game, wins)
        else:
            if int(game['sc']) < int(lsa[0]['sc']):
                lsa = (game, wins)
if wins == 0:
    print('No ascensions for %s.' % games[0]['name'])
else:
    print('\n%s. :%s:' % (str(lsa[1]), str(munge_game(lsa[0]))))
