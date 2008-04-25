#!/usr/bin/python

import sys, re
from helper import *

lcbranches_abbrev = [string.lower(abbrev) for abbrev in branches_abbrev]
lclevels_abbrev = [string.lower(level) for level in levels_abbrev]

help("Lists the top ten players to die in a certain place.")

placestring = sys.argv[3].split(' ')[1]
if ':' in placestring:
    branch, level = placestring.split(':')
    level = int(level)
else:
    if placestring.isdigit():
        branch, level = 'D', int(placestring)
    else:
        branch, level = placestring, ''

branch = branch.lower()
branch_aliases = dict([('mines','orc'),('v','vault'),('vaults','vault'),('hall', 'blade'), ('blades', 'blade'), ('tartarus', 'tar'),('gehenna','geh'),('cocytus','coc')])
if branch in branch_aliases:
    branch = branch_aliases[branch]
if branch not in lcbranches_abbrev and branch not in lclevels_abbrev:
    print "I don't know where that is!"
    sys.exit()
games = deaths_in(branch, level)
if not games:
    if level:
        level = ':' + str(level)
    print("No one has died in %s%s." % (branch, level))
    sys.exit()

deaths = []
uniq_deaths = [] 
deathcount = 0
for game in games:
    if game['ktyp'] in ('quitting', 'leaving', 'winning'): # Quits, escapes, and wins don't count
        continue 
    deathcount += 1

    death = game['name']
    deaths.append(death)
    if death not in uniq_deaths:
        uniq_deaths.append(death)

if deathcount == 0:
    print("No deaths here.")
    sys.exit()
if len(deaths) == 1: deathstring = "1 death"
else: deathstring = "%s deaths" % str(len(deaths))
if branch in lclevels_abbrev:
    branchstring = games[0]['ltyp']
else: #branch in lcbranches_abbrev
    branchstring = games[0]['br']

uniq_deaths.sort(lambda x,y: cmp(deaths.count(y),deaths.count(x)) or cmp(x,y))
freqstring = ''
numstats = 0
if level:
    level = ':' + str(level)
for death in uniq_deaths:
    if numstats > 9:
        break
    numstats +=1
    freqstring += "%dx %s(%.2f%%) " % (deaths.count(death), death, 
            100*deaths.count(death)/float(len(deaths)))
print("%s in %s%s. Most frequent: %s" % (deathstring, branchstring, level, freqstring))
