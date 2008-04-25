#!/usr/bin/python

import sys
from helper import *

help("Lists a player's longest winning streak. Priority is given to the oldest streak unless a current streak meets it.")


nick = sys.argv[1]
games = games_for(nick)
if len(games) == 0:
    print("No games for %s." % nick)
    sys.exit()

wins = 0
curstreak = 0
curstring = ''
beststreak = 0
beststring = ''

bestbetween = 1000000000000000000 #Stupid hack, could be fixed
curbetween = 0

streaks = []
for game in games:
    if game['ktyp'] == 'winning':
        curstreak += 1
        wins += 1
        curstring += game['char'] + ', '
        if curstreak > beststreak:
            beststreak = curstreak
            beststring = curstring
        if curbetween < bestbetween:
            bestbetween = curbetween
        curbetween = 0
    else:
    	if curstreak > 1:
	    streaks.append(curstring)
        curstreak = 0
        curstring = ''
        curbetween += 1

streaks.sort(lambda a,b: cmp(len(b), len(a)))

if curstreak == beststreak:
    beststreak = 0

gamestring = 'games'
if games == 1:
    gamestring = 'game'

if wins == 0:
    print("%s has not won in %d game%s." % (games[0]['name'], len(games), plural(len(games))))
    sys.exit()



elif wins == 1:
    if curbetween == 0:
        print("%s has one win in %d game%s, and can keep going!" % (games[0]['name'], len(games), plural(len(games))))
    else:
        print("%s has one win in %d game%s, and has played %d game%s since." % (games[0]['name'], len(games), plural(len(games)), curbetween, plural(curbetween)))

elif wins == 2 and bestbetween > 0:
    if curbetween == 0:
        print("%s has 2 unconsecutive wins but has just won, and can keep going!" % (games[0]['name']))
    else:
        print("%s has 2 wins, with %d game%s in between." % (games[0]['name'], bestbetween, plural(bestbetween)))

elif bestbetween > 0:
    if curbetween == 0:
        print("%s has %d wins, none consecutive, but has just won, and can keep going!" % (games[0]['name'], wins))
    else:
        print("%s has %d wins, none consecutive, but has a minimum of %d game%s between wins." % (games[0]['name'], wins, bestbetween, plural(bestbetween)))

elif beststreak > curstreak:
    if curstreak > 0:
        curstring = curstring[:-2] + '.'
        print("%s has %d consecutive wins: %sand has won their past %d game%s: %s" % (games[0]['name'], beststreak, beststring, curstreak, plural(curstreak), curstring))
    else:
    	beststring = '; '.join([s[:-2] for s in streaks if len(s) == len(beststring)])
        print("%s has %d consecutive wins: %s." % (games[0]['name'], beststreak, beststring))

else:
    curstring = curstring[:-2] + '.'
    print("%s has %d consecutive wins (and can keep going!): %s" % (games[0]['name'], curstreak, curstring))

