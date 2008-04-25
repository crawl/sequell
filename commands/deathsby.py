#!/usr/bin/python

import sys, re
from helper import *

help("Lists a player's 10 most frequent causes of death.")

player = sys.argv[1]
    
games = games_for(player)
if not games:
    print "No games for %s." % player
    sys.exit()

deaths = []
uniq_deaths = [] 
deathcount = 0
for game in games:
    ktyp = game['ktyp']
    if ktyp in ['quitting', 'leaving', 'winning']: # Quits, escapes, and wins don't count
        continue 
    deathcount += 1
    if ktyp in ['beam', 'mon']:
        source = game['killer']
        for char, index in zip(source[1:3], [1,2]):
            if ' ' == char:
                source = source[index + 1:]
    else:
        source = ktyp

    deaths.append(source)
    if source not in uniq_deaths:
        uniq_deaths.append(source)

if deathcount == 0:
    print("No deaths for %s! Wow!" % player)
    sys.exit()
if len(deaths) == 1: deathstring = "1 death"
else: deathstring = "%s deaths" % str(len(deaths))

uniq_deaths.sort(lambda x,y: cmp(deaths.count(y),deaths.count(x)) or cmp(x,y))
freqstring = ''
numstats = 0
for death in uniq_deaths:
    if numstats > 9:
        break
    numstats +=1
    freqstring += "%dx %s(%.2f%%) " % (deaths.count(death), death, 
            100*deaths.count(death)/float(len(deaths)))
print("%s for %s. Most frequent: %s" % (deathstring, player, freqstring))
