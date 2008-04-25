#!/usr/bin/python

import sys
from helper import *

keywords = ['runes', 'lvl', 'where', 'dlvl', 'killer', 'race', 'role', 'char','max','min','won','sort','show']
minmaxkeywords = ['runes', 'lvl', 'score', 'points', 'time', 'hp', 'dex', 'int', 'str', 'turns', 'turn']

statskeywords = ['score','points','turns', 'turn', 'time', 'runes', 'int','dex',
            'str', 'piety', 'penance', 'lvl', 'hp']
arg2stat = dict([('score','points'),('time','real_time'),('runes','num_runes'),
                 ('hp','final_max_hp'),('turn','turns'),('killer','death_source_name')])
arg2display = dict([('dlvl','death'),('time','game'),
                    ('runes','runes'),('final_max_hp','hp')])

stats = {}

lcbranches_abbrev = [string.lower(abbrev) for abbrev in branches_abbrev]
lclevels_abbrev = [string.lower(level) for level in levels_abbrev]
lcroles_abbrev = [string.lower(role) for role in roles_abbrev]
lcraces_abbrev = [string.lower(race) for race in races_abbrev]

argstring = sys.argv[3]
argstring = argstring.split(' ')
cmd = argstring.pop(0)[1:]
argstring = ' '.join(argstring)

if cmd == 'listgame':
    help("Lists a specifically-numbered game by a player with specified conditions. By default it lists the most recent game. Usage: !listgame (<player>) (<gamenumber>) (option list) where option list is in the form -opt=value, or -(max|min)=value")
elif cmd == 'stats':
    help("Lists information about various statistics for all of a player's games. See help on listgame for syntax.")

args, opts = parse_argstring(argstring)
for arg in args:
    arg = arg.replace('_', ' ')
for opt in opts:
    opts[opt] = opts[opt].replace('_', ' ')
num = '-1'
if not args:
    nick = sys.argv[2]
    num = '-1'
else:
    if args[0].isalnum() and not args[0].isdigit():
        nick = args[0]
    elif args[0] == '*':
        nick = '*'
    else:
        nick = sys.argv[2]
    for arg in args:
        if arg.isdigit():
            num = int(arg) # In case someone specifies a positive for gamenum
            break
showstat = ''

for key in opts.keys():
    if key.isdigit():
        num = -1 * int(key) # In case someone specifies a negative for gamenum
        continue
    if key not in keywords:
        print("%s is not a valid selector!" % (key))
        sys.exit()
    #if not opts[key]: may need this later, for options without values (-opt)

    if key == 'where' or key == 'dlvl':
        if opts[key].isdigit():
            stats['branch'] = "d"
            stats['dlvl'] = int(opts[key])
        elif opts[key].count(':') == 1:
            foo = opts[key].split(':')
            stats['branch'], stats['dlvl'] = foo[0], int(foo[1])
        else: # Only branch specified
            stats['branch'] = opts[key]
        if stats['branch'] in lclevels_abbrev and stats['branch'] != 'd':
            stats['level_type'] = lclevels_abbrev.index(stats['branch'])
            del stats['branch']
        else:
            if stats['branch'] not in lcbranches_abbrev:
                print("Unknown branch.")
                sys.exit()
            stats['branch'] = lcbranches_abbrev.index(stats['branch'])

    elif key == 'char':
        if len(opts[key]) != 4:
            print("Unknown char.")
            sys.exit()
        stats['race'], stats['role'] = opts[key][:2], opts[key][2:]
        if stats['race'] not in lcraces_abbrev or stats['role'] not in lcroles_abbrev:
            print("Unknown char.")
            sys.exit()
        stats['race'] = lcraces_abbrev.index(stats['race'])
        stats['role'] = lcroles_abbrev.index(stats['role'])

    elif key == 'race':
        if len(opts[key]) != 2 or opts[key] not in lcraces_abbrev:
            print("Unknown race.")
            sys.exit()
        stats['race'] = lcraces_abbrev.index(opts[key])

    elif key == 'role':
        if len(opts[key]) != 2 or opts[key] not in lcroles_abbrev:
            print("Unknown role.")
            sys.exit()
        stats['role'] = lcroles_abbrev.index(opts[key])

    elif key == 'max' or key =='min' or key == 'sort':
        if opts[key] not in minmaxkeywords:
            print("Unknown stat %s." % opts[key])
            sys.exit()
        if arg2stat.has_key(opts[key]):
            opts[key] = arg2stat[opts[key]]
        stats[key] = opts[key]
    elif key =='won':
        if opts[key] == 'no':
            stats['death_type'] = 'lost'
        else:
            stats['death_type'] = 12
    elif key == 'show':
        if opts[key] in statskeywords:
            if arg2stat.has_key(opts[key]):
                opts[key] = arg2stat[opts[key]]
            showstat = opts[key]
        else:
            print("Unknown stat %s." % opts[key])
            sys.exit()
    else:
        oldkey = key
        if arg2stat.has_key(oldkey):
            key = arg2stat[oldkey]
        stats[key] = string.lower(opts[oldkey])

#list = [(field, stats[field]) for field in stats]
list = []
for field in stats:
    if field in statskeywords:
        list.append((field, stats[field]))

if nick != '*':
    list.insert(0, ('name', nick))

potentialgames = games_such_that(list)
if len(potentialgames) == 0:
    print("No such games.")
    sys.exit()

games = []
for game in potentialgames:
    include = 0
    if len(stats.keys()) == 0 or (len(stats.keys()) == 1 and (stats.keys()[0] == 'max' or stats.keys()[0] == 'min' or stats.keys()[0] == 'sort')):
        games.append(game)
        continue
    for stat in stats.keys():
        if stat == 'death_source_name':
            if stats[stat] and stats[stat] not in (string.lower(game[stat]), game[stat][2:], game[stat][3:]):
                include = 0
                break
            else:
                include = 1
                continue
        if stat == 'max' or stat == 'min' or stat == 'sort':
            continue
        if stats[stat] and game[stat] != stats[stat]:
            include = 0
            break
        else:
            include = 1
    if include:
        games.append(game)

if len(games) == 0:
    print("No games fit those criteria.")
    sys.exit()

num = int(num)
if abs(num) > len(games):    
    print("No games fit those criteria.")
    sys.exit()
if abs(num) == 0:
    print("Invalid game number. Numbering starts at 1; reverse numbering starts at -1.")
    sys.exit()


if num < 0:
    num += len(games)
else:
    num -= 1

minmaxstring = ""
max, min = 0, 1000000000000000000000000

if 'sort' in stats.keys():
    def comparestat(x, y):
        return cmp(x[stats['sort']], y[stats['sort']])
    games.sort(comparestat)
    if stats['sort'] not in ("points", "turns", "real_time"):
        minmaxstring = " (%s %s)" % (games[num][stats['sort']], stats['sort'])

for _type in ('min', 'max'):
    if _type not in stats.keys():
        continue
    def comparestat(x, y):
        return cmp(x[stats[_type]], y[stats[_type]])

    games.sort(comparestat)
    if _type == 'min':
        games.reverse()
    if stats[_type] not in ("points", "turns", "real_time"):
        minmaxstring = " (%s %s)" % (games[num][stats[_type]], stats[_type])

if cmd == 'listgame':
    print('\n%s. %s%s' % (games[num]['_num'], str(munge_game(games[num])), minmaxstring))
elif cmd == 'stats':
    if not showstat:
        showstat = 'points'
    displaystat = showstat
    if arg2display.has_key(showstat):
        displaystat = arg2display[showstat]
    wongames = []
    lostgames = []
    total = 0.0
    iqtot = 0.0
    if 'sort' not in opts.keys() and 'max' not in opts.keys() and 'min' not in opts.keys():
        games.sort(lambda x,y: cmp(x[showstat],y[showstat]))
        
    quartersize = int(len(games)/4)
    for i in xrange(len(games)):
        total += games[i][showstat]
        if games[i]['death_type'] == 12:
            wongames.append(games[i])
        if i > quartersize and i <= len(games) - quartersize:
            iqtot += games[i][showstat]


    gameslist = games

    highstat = gameslist[-1][showstat]
    lowstat = gameslist[0][showstat]
    mean = total/len(gameslist)
    median = gameslist[int(len(gameslist)/2)][showstat]

    if len(games) == 1:
        iqm = mean
    else:
        iqm = iqtot/(len(games) - (2*quartersize))
    best = 'highest'
    worst = 'lowest'
    if showstat == 'real_time':
        highstat,lowstat,mean,median,iqm = tuple(map(serialize_time,(highstat,lowstat,mean,median,iqm)))

        best = 'longest'
        worst = 'shortest'
    else:
        mean,iqm = map(lambda x: str('%.2f' % x),(mean,iqm))
        if showstat == 'num_runes' or showstat == 'turns':
            best = 'most'
            worst = 'fewest'
        elif showstat == 'dlvl':
            best = 'deepest'
            worst = 'shallowest'
    if nick == '*':
        namestring = 'Users have'
    else:
        namestring = games[0]['name'] + ' has'
    playedstring = str(len(games)) + ' such games'
    if len(games) == 1:
        playedstring = '1 such game'
    winstring = ''
    if len(wongames) != 0:
        winstring = 'played ' + playedstring + ', won ' + once(len(wongames))
    else:
        winstring = 'played ' + playedstring

    print('%s %s: %s %s %s, %s %s, median %s, mean %s, interquartile mean %s.' % (namestring,
              winstring, best, displaystat, str(highstat),
              worst, str(lowstat), str(median), str(mean), str(iqm)))
