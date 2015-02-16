# JSON API (experimental)

Sequell provides access to the LearnDB and some game queries as a JSON API
over https.

Sequell's current official API endpoint is https://loom.shalott.org/api/sequell
All API URL paths in this document are relative to the API endpoint.

All API access is experimental and may change with no warning.


## LearnDB

Sequell provides read-only access to the LearnDB at `/ldb`. There are
two forms of LearnDB query:

* Direct term lookup with `term=X`:

         $ curl 'https://loom.shalott.org/api/sequell/ldb?term=zot' | json_pp
         {
             "chosenIndex": 1,
             "definitions": [
                 "The final area of the game, although not necessarily the very last realm any player ever goes to. Filled with draconians, dragons, and all sorts of nasty types out to obliterate you. Found on Depths:5, and you can only unlock it with with 3 or more runes (found in dungeon branches). Five levels deep.",
                 "Mind the gaps in your resistances while you are down here, especially fire and electricity- electric golems and orbs of fire in particular are infamously strong. Use potions of resistance, seriously.",
                 "see {the wizards castle}",
                 "http://www.funtrivia.com/askft/Question43380.html",
                 "Before DCSS 0.1.3, the main enemies in Zot were deep elves instead of draconians.",
                 "<bmfx> crawl doesn't hate me... he just puts these TWO zot traps diconnecting one z:5 lung and a tele trap disconnecting the other just for laughs :("
             ],
             "originalLookup": "zot",
             "term": "zot"
         }       

* LearnDB searches with `search=X`:

         $ curl 'https://loom.shalott.org/api/sequell/ldb?search=neqoxec' | json_pp
         {
             "entries": [
                 {
                     "index": 1,
                     "term": "3",
                     "text": "The tier 3 demons. They are: {sun demon}, {smoke demon}, {soul eater}, {neqoxec}, {ice devil}, {chaos spawn}, {ynoxinul}."
                 },
                 {
                     "index": 4,
                     "term": "demonspawn",
                     "text": "Classes include {warmonger}, {blood saint}, {chaos champion}, {black sun}, and {corrupter}, on top of said bases (and all but blood saints are priests). Base demonspawn are fodder by pan
          time, bases and classes each have chances for themed/mixed bands, singular placements in pan lord vaults, and cut into neqoxec/smoke demon pan spawns."
                 }
             ],
             "terms": [
                 "neqoxec"
             ]
         }

## Listgame

Listgame access uses the `/game` and `/milestone` endpoints for completed games
and milestones, respectively.

### Parameters

* Use `index=N` to request a game at a specific index.
* Use `count=N` to request a specific number of games.
* Use `X=Y` to add a `X=Y` filter to your !lg / !lm query. See [the listgame doc](listgame.md) for filter options. Note that you cannot specify keywords and similar parameters as top-level request parameters. If you have a complex query, use the `q=X` form.
* Use `q=X` to specify a full !lg/!lm query. This overrides all other parameters.

         $ curl -s 'https://loom.shalott.org/api/sequell/game?q=!lg+*+win'
         {"resultTime":"2015-02-16T03:29:30+01:00","entity":"game","records":[{"id":3972261,"offset":221888953,"game_key":"Nemora:cao:20150103172929S","file":"remote.cao-logfile-git","alpha":true,"src":"cao","explbr":"","v":"0.16.0-a0","cv":"0.16-a","vlong":"0.16-a0-4008-gc88e425","lv":"0.1","sc":11202654,"name":"Nemora","race":"Red Draconian","crace":"Draconian","cls":"Fire Elementalist","char":"DrFE","xl":27,"sk":"Translocations","sklev":27,"title":"Plane Walker","ktyp":"winning","killer":"","ckiller":"winning","ikiller":"","cikiller":"","kpath":"","kmod":"","kaux":"","ckaux":"","place":"D:$","br":"D","lvl":0,"absdepth":1,"ltyp":"","hp":254,"mhp":254,"mmhp":254,"mp":25,"mmp":58,"bmmp":49,"dam":-9999,"sdam":0,"tdam":0,"str":14,"int":42,"dex":21,"god":"Vehumet","piety":200,"pen":0,"wiz":false,"start":"20150103172929S","end":"20150116015733S","dur":"15:59:29","turn":148720,"urune":15,"nrune":15,"tmsg":"escaped with the Orb","vmsg":"escaped with the Orb and 15 runes!","rstart":"20150103172929S","rend":"20150116015733S","ntv":0,"map":"lightli arrival windingriver","killermap":"","mapdesc":"","tiles":true,"gold":8840,"goldfound":18213,"goldspent":9373,"zigscompleted":1,"zigdeepest":27,"scrollsused":179,"potionsused":106,"kills":8576,"ac":24,"ev":35,"sh":18,"aut":1474078,"maxskills":"Conjurations,Translocations","fifteenskills":"Fighting,Long Blades,Dodging,Spellcasting,Conjurations,Charms,Necromancy,Translocations,Fire Magic,Earth Magic,Evocations","status":"studying Fighting,deflect missiles","banisher":"","cbanisher":"","vnum":1600001000000,"cvnum":1600001000000,"vlongnum":1600001004008,"file_cv":"git","sql_table":"logrecord","qualified_index":"25588","index":25588,"n":25588,"count":25588}]}
