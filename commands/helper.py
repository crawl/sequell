#!/usr/bin/python
import string, re, os, sys
import os.path
from glob import glob

logfile = '/var/www/crawl/allgames.txt'

www_rawdatapath = '/var/www/crawl/rawdata/'

xkeychars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_'

adjective_skills = \
  dict( [ (title, True) for
          title in [ 'Deadly Accurate', 'Spry', 'Covert', 'Unseen' ] ] )

adjective_end = re.compile(r'(?:ed|ble|ous)$')

details_names = ['v', 'lv', 'name', 'uid', 'race', 'cls', 'xl', 'sk', 'sklev',
                 'title', 'place', 'br', 'lvl', 'ltyp', 'hp', 'mhp', 'mmhp',
                 'str', 'int', 'dex', 'start', 'dur', 'turn', 'sc', 'ktyp',
                 'killer', 'kaux', 'end', 'tmsg', 'vmsg', 'god', 'piety',
                 'pen', 'char', 'nrune', 'urune']

races =        ['Null', 'Human', 'Elf', 'High Elf', 'Grey Elf', 'Deep Elf',
                'Sludge Elf', 'Hill Dwarf', 'Mountain Dwarf', 'Halfling',
                'Hill Orc', 'Kobold', 'Mummy', 'Naga', 'Gnome', 'Ogre', 'Troll',
                'Ogre Mage', 'Red Draconian', 'White Draconian',
                'Green Draconian', 'Golden Draconian', 'Grey Draconian',
                'Black Draconian', 'Purple Draconian', 'Mottled Draconian',
                'Pale Draconian', 'Unk0 Draconian', 'Unk1 Draconian',
                'Base Draconian', 'Centaur', 'Demigod', 'Spriggan', 'Minotaur',
                'Demonspawn', 'Ghoul', 'Kenku', 'Merfolk', 'Vampire', 'Deep Dwarf']

races_abbrev = ["XX", "Hu", "El", "HE", "GE", "DE", "SE", "HD", "MD", "Ha",
                "HO", "Ko", "Mu", "Na", "Gn", "Og", "Tr", "OM", "Dr", "Dr",
                "Dr", "Dr", "Dr", "Dr", "Dr", "Dr", "Dr", "Dr", "Dr", "Dr",
                "Ce", "DG", "Sp", "Mi", "DS", "Gh", "Ke", "Mf", "Vp", "DD"]

god_names = ['None','Zin','The Shining One','Kikubaaqudgha','Yredelemnul','Xom',
             'Vehumet','Okawaru','Makhleb','Sif Muna','Trog','Nemelex Xobeh',
             'Elyvilon']
god_names_abbrev = ['None','Zin','TSO','Kiku','Yred','Xom','Vehumet','Okie',
                    'Makhleb','Sif','Trog','Nemelex','Ely']

roles =  ["Fighter","Wizard", "Priest", "Thief", "Gladiator", "Necromancer",
          "Paladin", "Assassin", "Berserker", "Hunter", "Conjurer", "Enchanter",
          "Fire Elementalist", "Ice Elementalist", "Summoner",
          "Air Elementalist", "Earth Elementalist", "Crusader", "Death Knight",
          "Venom Mage", "Chaos Knight", "Transmuter", "Healer", "Quitter",
          "Reaver", "Stalker", "Monk", "Warper", "Wanderer", "Artificer"]
roles_abbrev =   ["Fi", "Wz", "Pr", "Th", "Gl", "Ne", "Pa", "As", "Be", "Hu",
                  "Cj", "En", "FE", "IE", "Su", "AE", "EE", "Cr", "DK", "VM",
                  "CK", "Tm", "He", "XX", "Re", "St", "Mo", "Wr", "Wn", "Ar"]

death_methods = [
  'killed by a monster',
  'succumbed to poison',
  'engulfed by something',
  'killed by a beam',
  'stepped on Death\'s door', #deprecated apparently
  'took a swim in molten lava',
  'drowned',
  'forgot to breathe',
  'collapsed under their own weight',
  'slipped on a banana peel',
  'killed by a trap',
  'got out of the dungeon',
  'escaped with the Orb',
  'quit the game',
  'was drained of all life',
  'starved to death',
  'froze to death',
  'burnt to a crisp',
  'killed by wild magic',
  'killed for Xom\'s enjoyment',
  'killed by a statue',
  'rotted away',
  'killed themself with bad targetting',
  'killed by an exploding spore',
  'smote by The Shining One',
  'turned to stone',
  '<deprecated>',
  'died somehow',
  'fell down a flight of stairs',
  'splashed by acid',
  'asphyxiated',
  'melted into a puddle',
  'bled to death',
]


skills = [("Skirmisher", "Grunt", "Veteran", "Warrior", "Slayer"),
  ("Stabber", "Cutter", "Knifefighter", "Eviscerator", "Blademaster"),
  ("Slasher", "Slicer", "Fencer", "Swordfighter", "Swordmaster"),
  ("Great sworder - you deprecated bastard!"),
  ("Chopper", "Cleaver", "Hacker", "Severer", "Axe Maniac"),
  ("Basher", "Cudgeler", "Shatterer", "Bludgeoner", "Skullcrusher"),
  ("Spear-Bearer", "Pike-Bearer", "Phalangite", "Lancer", "Halberdier"),
  ("Twirler", "Cruncher", "Smasher", "Stickfighter", "Skullbreaker"),
  ("Vandal", "Slinger", "Whirler", "Crazy", "Very Crazy"),
  ("Shooter", "Yeoman", "Archer", "Merry", "Merry"),
  ("Shooter", "Sharpshooter", "Archer", "Ballista", "Ballista"),
  ("Dart Thrower", "Hurler", "Hurler, First Class", "Darts Champion", "Universal Darts Champion"),
  ("Chucker", "Thrower", "Deadly Accurate", "Hawkeye", "Sniper"),
  ("Covered", "Protected", "Tortoise", "Impregnable", "Invulnerable"),
  ("Ducker", "Dodger", "Nimble", "Spry", "Acrobat"),
  ("Footpad", "Sneak", "Covert", "Unseen", "Imperceptible"),
  ("Miscreant", "Blackguard", "Backstabber", "Cutthroat", "Politician"),
  ("Shield-Bearer", "Blocker", "Barricade", "Peltast", "Hoplite"),
  ("Disarmer", "Trapper", "Architect", "Engineer", "Dungeon Master"),
  ("Ruffian", "Grappler", "Brawler", "Wrestler", "Boxer"),
  ("none"),
  ("none"),
  ("none"),
  ("none"),
  ("none"),
  ("Magician", "Thaumaturge", "Eclecticist", "Sorcerer", "Archmage"),
  ("Ruinous", "Conjurer", "Destroyer", "Devastator", "Annihilator"),
  ("Charm-Maker", "Infuser", "Bewitcher", "Enchanter", "Spellbinder"),
  ("Caller", "Summoner", "Convoker", "Demonologist", "Hellbinder"),
  ("Grave Robber", "Reanimator", "Necromancer", "Thanatomancer", "Character of Death"),
  ("Jumper", "Blinker", "Shifter", "Portalist", "Plane Walker"),
  ("Changer", "Transmogrifier", "Transformer", "Alchemist", "Transmuter"),
  ("Seer", "Soothsayer", "Diviner", "Augur", "Oracle"),
  ("Firebug", "Arsonist", "Scorcher", "Pyromancer", "Infernalist"),
  ("Chiller", "Frost Mage", "Ice Mage", "Cryomancer", "Englaciator"),
  ("Wind Mage", "Cloud Mage", "Air Mage", "Sky Mage", "Storm Mage"),
  ("Digger", "Geomancer", "Earth Mage", "Metallomancer", "Petrodigitator"),
  ("Stinger", "Tainter", "Polluter", "Poisoner", "Envenomancer"),
  ("Believer", "Servant", "Worldly Agent", "Theurge", "Avatar"),
  ("Charlatan", "Prestidigitator", "Fetichist", "Evocator", "Talismancer"),
  ("none"),
  ("none"),
  ("none"),
  ("none"),
  ("none"),
  ("none"),
  ("none"),
  ("none"),
  ("none"),
  ("none"),
  ("none")
]

level_types = [("in the main dungeon"),
  ("in a labyrinth"),
  ("in the Abyss"),
  ("in Pandemonium")
]

levels_abbrev = ["D", "Lab","Abyss","Pan"]

branches = [("of the main dungeon"),
  ("of Dis"),
  ("of Gehenna"),
  ("in the Vestibule of Hell"),
  ("of Cocytus"),
  ("of Tartarus"),
  ("of the Inferno"),
  ("of the Pit"),
  ("null"),
  ("null"),
  ("of the Mines"),
  ("of the Hive"),
  ("of the Lair"),
  ("of the Slime Pits"),
  ("of the Vaults"),
  ("of the Crypt"),
  ("in the Hall"),
  ("of Zot's Hall"),
  ("in the Temple"),
  ("of the Snake Pit"),
  ("of the Elf Hall"),
  ("of the Tomb"),
  ("of the Swamp")
]
branches_abbrev = ["D","Dis","Geh","Hell","Coc","Tar",
                   "Inferno","Pit","null","null","Orc","Hive","Lair","Slime",
                   "Vault","Crypt","Blade","Zot","Temple","Snake","Elf","Tomb",
                   "Swamp"]
lcbranches_abbrev = [string.lower(abbrev) for abbrev in branches_abbrev]
lclevels_abbrev = [string.lower(level) for level in levels_abbrev]

WHERE_DIRS = None

NICK_ALIASES = { }
NICKMAP_FILE = 'nicks.map'
nick_aliases_loaded = False

def game_skill_title(game):
    title = game['title']
    turns = game['turn']
    if int(turns) < 200000:
        return title
    else:
        return game_skill_farming(title)

def game_skill_farming(title):
    if adjective_skills.has_key(title) or adjective_end.search(title):
        return title + " Farmer"
    else:
        return "Farming " + title

def plural(int):
    if int > 1:
        return 's'
    else:
        return ''

def ntimes(times):
    if times == 1: return 'once'
    elif times == 2: return 'twice'
    elif times == 3: return 'thrice'
    else: return str(times) + ' times'

def canonicalize_nick(nick):
    global WHERE_DIRS
    if WHERE_DIRS is None:
        WHERE_DIRS = [ f for f in glob(www_rawdatapath + '/*')
                       if os.path.isdir(f) ]
    lnickw = '/' + nick.lower()
    match = [ x for x in WHERE_DIRS if x.lower().endswith(lnickw) ]
    return len(match) > 0 and extract_nick_from_wherepath(match[0]) or None

def canonicalize_nicks(nicks):
    return [ n for n in [ canonicalize_nick(x) for x in nicks ] if n ]

def extract_nick_from_wherepath(wherepath):
    windex = wherepath.rfind('/')
    if windex == -1:
	return None
    where = wherepath[windex + 1 : ]
    if os.path.isfile(wherepath + '/' + where + '.where'):
    	return where

def strip_extension(name):
    dotind = name.rfind('.')
    return dotind == -1 and name or name[0 : dotind]

def once(times):
    if times == 1: return 'once'
    elif times == 2: return 'twice'
    elif times == 3: return 'thrice'
    else: return str(times)

def replace(string, toreplace, replacewith):
    while string.count(toreplace) > 0:
        string = string[:string.index(toreplace)] + replacewith + string[string.index(toreplace) + len(toreplace):]
    return string

def parse_argstring(argstring): # Takes a string of everything after !cmd.
    arglist = []
    if not argstring:
        return [], {}
    if argstring.count('"') % 2:
        print("Missing a quote mark?")
        sys.exit()
    if argstring.count('"') == 0:
        arglist = argstring.split(' ')
    else:
        i = 0
        quotelist = argstring.split('"')
        for string in quotelist:
            if not i % 2 and string: # if this is outside of quotes and exists
                list = string.split(' ')
                if not list[0]:
                    list = list[1:]
                # join the quoted material with the string before it
                if len(quotelist) > i + 1:
                    list[-1] = ''.join([list[-1], quotelist[i + 1]])
                    arglist.extend(list)
            i += 1
    # Now we have the One True Arglist. parse using parse_argslist.
    return parse_argslist(arglist)

def parse_argslist(argslist):
    # Takes a list of everything after the !command. (sys.argv[3].split(' ')[1:]
    # Returns args, opts
    args = []
    opts = []
    optlist = []
    if len(argslist) == 1 and len(argslist[0]) == 0:
        return args, dict(opts)
    for arg in argslist:
        if arg[0] == '-':
            optlist.append(arg[1:])
        else:
            args.append(string.lower(arg))
    for opt in optlist:
        opt = string.lower(opt)
        if '=' in opt and opt.split('=')[0] and opt.split('=')[1]:
            opts.append(tuple(opt.split('=')[:2]))
        else:
            opts.append((opt, ''))
    return args, dict(opts)

def munge_game(game):
    logline = ''
    for detail in details_names:
        try:
            game[detail] # try to catch a keyerror early
            logline += detail + '=' + str(game[detail]).replace(':', '::') + ':'
        except KeyError:
            continue

    logline = logline[:-1]
    return logline

def demunge_logline(logline):
    details = dict(zip(details_names, logline.split(':')[1:-1]))
    for key, detail in details.iteritems():
        try:
            details[key] = int(detail)
        except:
            pass
    return details

def demunge_xlogline(logline):
    if not logline:
        return {}
    if logline[0] == ':' or (logline[-1] == ':' and not logline[-2] == ':'):
        sys.exit(1)
    if '\n' in logline:
        sys.exit(1)
    logline = replace(logline, "::", "\n")
    details = dict([(item[:item.index('=')], item[item.index('=') + 1:]) for item in logline.split(':')])
    for key in details:
        for char in key:
            if char not in xkeychars:
                sys.exit(1)
        details[key] = replace(details[key], "\n", ":")
    return details

def games_for(nick):
    nick = string.lower(nick)
    filter = re.compile('[^a-z0-9]')
    nick = filter.sub('',nick)
    potentialgames = os.popen("grep -i 'name=" + nick + ":' " + logfile).readlines()
    games = []
    i = 1
    for potentialgame in potentialgames:
        game = demunge_xlogline(potentialgame[:-1])
        if string.lower(game['name']) == nick:
            game['_num'] = i
            games.append(game)
            i += 1
    return games

def games_such_that(list): # list = [(field, value),(field2, value2)]
    filter = re.compile('[^a-z0-9]')
    namefilter = re.compile('[0-9]+$')
    grepstring = ''
    for item in list:
        field, value = item
        if field == 'place':
            value = value.replace(':','::')
        else:
            value = string.lower(str(value))
            value = filter.sub('',value)
            if field == 'name':
                value = namefilter.sub('',value)
        if field == 'killer':
            grepstring += " | grep -Ei ':killer=(an? )?" + value + ":'"
        else:
            grepstring += " | grep -i ':" + field + "=" + value + ":'"
    potentialgames = os.popen("cat " + logfile + grepstring).readlines()

    games = []
    i = 1
    for potentialgame in potentialgames:

        game = demunge_xlogline(potentialgame[:-1])
        game['_num'] = i
        games.append(game)
        i += 1
    return games

def allgames():
    games = []
    i = 1
    for game in os.popen("cat " + logfile).readlines():
        game = demunge_xlogline(game)
        game['_num'] = i
        games.append(game)
        i += 1
    return games



def deathstring(game):
    deathstring = ''
    if game['death_type']:
        deathstring = death_methods[game['death_type']]
        if game['death_source_name']:
            deathstring += " - %s" % game['death_source_name']
    else:
        deathstring = "killed by %s" % game['death_source_name']
    if game['auxkilldata']:
        deathstring += " (%s)" % game['auxkilldata']
    return deathstring

def deaths_in(branch, level):
    branch = string.lower(branch)
    filter = re.compile('[^a-z0-9 -]')
    branch = filter.sub('',branch)

    if branch in lclevels_abbrev and branch != 'd':
        level_type = branch
        postbranchstr = 'ltyp=' + level_type + ':'
        prebranchstr = ''
    else:
        level_type = ''
        if branch not in lcbranches_abbrev:
            print("Unknown branch. Borkage! Borkage, will robinson!")
            sys.exit()
        prebranchstr = ':place=' + str(branch) + ':'
        postbranchstr = ''


    if not level:
        levelstr = ''
    else:
        levelstr = 'lvl=' + str(level) + ':'
    potentialgames = os.popen("grep -i '" + prebranchstr + levelstr + postbranchstr + "' " + logfile).readlines()
    games = []
    i = 0
    for potentialgame in potentialgames:
        game = demunge_xlogline(potentialgame[:-1])
        game['_num'] = i
        games.append(game)
        i += 1
    return games

def kills_by(monster):
    monster = monster.replace("'", "")
    if monster in ('pois', 'starvation', 'stupidity', 'water', 'burning',
                   'draining', 'weakness', 'cloud', 'lava', 'clumsiness',
                   'trap', 'freezing', 'wild_magic', 'statue', 'rotting',
                   'targeting', 'spore', 'falling_down_stairs', 'petrification',
                   'acid', 'curare', 'melting', 'bleeding', 'statue', 'xom',
                   'tso_smiting', 'deaths_door'):
        potentialgames = os.popen("grep -i ':ktyp=" + monster + ":' " + logfile).readlines()
    else:
        monster = string.lower(monster)
        filter = re.compile('[^a-z0-9 -]')
        monster = filter.sub('',monster)
        if "s ghost" in monster:
            monster = monster[:-7] + "'" + monster[-7:]
            potentialgames = os.popen('grep -i ":killer=' + monster + ':" ' + logfile).readlines()
        else:
            potentialgames = os.popen("grep -Ei ':killer=(an? )?" + monster + ":' " + logfile).readlines()

    games = []
    i = 0
    for potentialgame in potentialgames:
        game = demunge_xlogline(potentialgame[:-1])
        game['_num'] = i
        games.append(game)
        i += 1
    return games

def serialize_time(s):
    return '%d:%02d:%02d' % (s/60/60%60, s/60%60, s%60)

def help(helpstring):
    if sys.argv[4]:
        print helpstring
        sys.exit()

def load_nick_aliases():
    global nick_aliases_loaded
    if nick_aliases_loaded:
        return NICK_ALIASES
    nick_aliases_loaded = True
    if os.path.exists(NICKMAP_FILE):
        for line in open(NICKMAP_FILE).readlines():
            nicks = line.split()
            if len(nicks) > 1:
                NICK_ALIASES[nicks[0].lower()] = " ".join(nicks[ 1 : ])
    return NICK_ALIASES

def nick_aliases(nick):
    load_nick_aliases()
    alias = NICK_ALIASES.get(nick.lower())
    if alias:
        return alias.split()
    else:
        return [ nick ]

def canonical_aliases(nick):
    return canonicalize_nicks(nick_aliases(nick))

def nick_alias(nick):
    return nick_aliases(nick)[0]
