#!/usr/bin/env python
import sys, string
import re
import helper

helper.help("Expands race/role abbreviations. Example usage: !wtf TrBe")

def expand_any(what, lookup, expanded):
    if what in lookup:
        return pick_first(expanded[ lookup.index(what) ])
    else:
        llookup = [ x.lower() for x in lookup ]
        lwhat = what.lower()
        if lwhat in llookup:
            return pick_first(expanded[ llookup.index(lwhat) ])
    return None

def pick_first(thing_or_list):
    return thing_or_list[0] if isinstance(thing_or_list, list) else thing_or_list

def expand_race(what):
    return expand_any(what, helper.SPECIES_ABBR, helper.SPECIES)

def expand_role(what):
    return expand_any(what, helper.ROLES_ABBR, helper.ROLES)

def expand(what):
    if what == '': return [ 'WTF?' ]
    if what.lower() == 'wtf': return [ 'WTFF!' ]

    args = re.findall(r'(?i)([a-z]{2})', what) or [ what ]
    if len(args) >= 2:
        ans = [expand_race(args[0]) or 'Unperson',
               expand_role(args[1]) or 'Unemployed']
        if ans[1] == 'Unemployed': ans.reverse()
        return ans
    elif len(args) == 1:
        return [ ' or '.join( [
            x for x in (expand_race(args[0]), expand_role(args[0])) if x ] ) or
            'WTF was that? Unthing!' ]

def split_abbr_line(line):
    return [ x.strip() for x in
             re.match(r'\s*(\S.*?\S)\s*=\s*(.*)', line).groups() ]

def load_abbrevs(file):
    misc = { }
    try:
        for line in open(file):
            abbr, exp = split_abbr_line(line)
            misc[abbr] = exp
    except IOError:
        pass
    return misc

def save_abbrevs(file, abbr):
    f = open(file, 'w')
    for key in abbr:
        if abbr[key].strip():
            f.write("%s=%s\n" % (key, abbr[key]))
    f.close()

def add_abbrev(abbr, what, who):
    key, val = split_abbr_line(what)
    abbr[key.lower()] = val and ("%s (ref: %s)" % (val, who)) or ''

def do_abbrv_thing(what, who):
    what = ' '.join(what.split(' ')[1:])
    canned_abbreviations = helper.CFG['wtf-lookup']
    if what.lower() in canned_abbreviations:
        return [ canned_abbreviations[what.lower()] ]
    return expand(what)

if __name__ == '__main__':
    if len(sys.argv) < 4:
        print "Need at least 3 arguments: <what> <who> <fullcmd>"
        sys.exit(1)

    print ' '.join( do_abbrv_thing( sys.argv[3], sys.argv[2] ) )
