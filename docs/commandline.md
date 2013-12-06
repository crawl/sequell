Command-Line Expansion
======================

Any command you issue to Sequell is expanded before execution. For
instance, if user "jake" runs a command as follows:

    <jake > .echo User is: $user

Sequell will respond with: "User is: jake"

The syntax used for command-line expansion is:

### Variables:

References such as `$user`, `$name`, etc. Any reference that Sequell does not
know how to expand will be canonicalized and echoed.

    <jake > .echo Hi $user => Hi jake
    <jake > .echo Hi $nobody => Hi ${nobody}

The variables that Sequell recognizes depend on the context:

 - Any context:

   `$user`: The name of the requesting user.

 - Listgame queries (!lg, etc.)

   `$name`: The name of the player (this may be a guess)
   `$target`: The first nick referenced in the query, possibly *
              !lg * fmt:"Name: $name, Target: $target"
              => Name: <whoever>, Target: *

### Subcommands:

A subcommand may be referenced as `$(<commandline>)`. For instance:

    .echo Characters played by *: $(!lg * s=char join:", ")
    => Characters played by *: SpEn, MiFi, ...

    .echo Hi $(.echo there) => Hi there

To see wins by characters that player 'foo' has played but not won:

    !lg * win char=$(!lg foo !won s=char join:"|")

Note: any command executing as a subcommand has no default title:

    .echo Chars: $(!lg . s=char) => MuPr, ...

An unknown subcommand will trigger an immediate error, unlike other
expansions, which will ignore unexpanded values.

### Functions:

Functions may be used as `$(fn ...)`.

   - `$(typeof <val>)`  returns the type of the given value

   - `$(join [<joiner>] <text>)`
         .echo $(join " and " a,b,c) => a and b and c

     The join function splits text on commas and joins it with the given
     join string. If omitted, the join string defaults to ", "

   - `$(split [<splitter>] <text>)`

     The split function splits text into an array on the given delimiter:

         .echo $(join $(split & a&b&c)) => a, b, c

   - `$(str-find <str> <text>)`; `$(str-find? <str> <text>)`
   
      `str-find` returns the index of <str> in <text>, indexes
      starting with 0, or -1 if <str> is not found in <text>. If
      merely checking for match/no-match, `str-find?` returns boolean
      true or false.

   - `$(re-find <regex> <text>)`
   
      Returns a match object if the regex matches the text.

      Match objects can be indexed with `elt`, or converted into a
      list of captures with `match-groups`. The indexes where the
      regex matched can be obtained using `match-begin` and `match-end`.

   - `$(match-groups <match>)`

     Returns a list of text groups captured by a regex search. The first
     item is always the full matching text of the regex.

   - `$(match-begin <match> [<group-index>])`

     Returns the start index in the original text where the regex matched. If
     *group-index* is specified, returns the start index where that particular
     capturing group matched.

   - `$(replace <string> [<replacement>] <text>)`

     The replace function replaces occurrences of `<string>` in `<text>` with
     `<replacement>`, the replacement defaulting to the empty string:

         .echo $(replace & ! a&b&c) => a!b!c
         .echo $(replace & a&b&c) => abc

   - `$(replace-n <n> <string> [<replacement>] <text>)`

     Like `replace`, but replaces only `n` occurrences. If `n` is -1,
     behaves exactly as `replace` does. If `n` is 0, returns the text
     unmodified.

   - `$(re-replace <regex> [<replacement>] <text>)`

     Like `replace`, but uses [RE2 regexps](https://code.google.com/p/re2/wiki/Syntax).

     `replacement` is lazily evaluated and may use captures as variables:
     
         .echo $(re-replace '\b([a-z])' (upper $1) "How now brown cow")
         => How Now Brown Cow

         .echo $(re-replace '\b\w(?P<letter>[a-z])\w\b' (upper $letter) "How now brown cow")
         => O O brown O

   - `$(re-replace-n <n> <regex> [<replacement>] <text)`

      Replaces only *n* matches; this is the regex equivalent of `replace-n`.

   - `$(upper <str>), $(lower <str>)`

     upper/lower-case text

   - `$(time)`

     Current time and date.

   - `$(utc <time>)`

     Converts *time* to UTC.

   - `$(ptime <text> [<format>])`

     Parses *text* to a time with the specified [*format*](http://pubs.opengroup.org/onlinepubs/009695299/functions/strptime.html)

     If *format* is omitted, the ISO 8601 date format (%FT%T%z) is assumed.

   - `$(interval-year [<x>])`, `$(interval-day [<x>])`,
     `$(interval-hour [<x>])`, `$(interval-minute [<x>])`,
     `$(interval-second [<x>])`

     Interprets <x> as an appropriate time interval, which can then be
     used in date arithmetic. A *year* is treated as a unit of 365 days, not
     a strict calendar year.

     For intervals of one day and larger, you may just use the appropriate
     numbers:

         .echo $(+ (time) 5)
         => <time 5 days in the future>

   - `$(ftime <time> [<format>])`

     Formats *time* to a string using the specified [*format*](http://pubs.opengroup.org/onlinepubs/009695299/functions/strptime.html)

     If *format* is omitted, the ISO 8601 date format (%FT%T%z) is assumed.

   - `$(length <string|array>)` String or array length
   - `$(sub <start> [<exclusive-end>] <string|array>)` Substring or array slice
   
   - `$(nth <index> <array>)` Index into array
   - `$(car <array>)` First element
   - `$(cdr <array>)` Array slice (identical to $(sub 1 <array>))
   - `$(rand n)` => random integers in [0,n)
   - `$(rand n m)` => random integers in [n,m]
   - Prefix operators: `+` `-` `/` `*` `=` `/=` `<` `>` `<=` `>=` `<=>` `**`
     `mod` `not`
   
          $(<=> 1 5) => -1
          $(<=> 1 1) => 0
          $(<=> 5 1) => 1
          
   - Type-casts: `str`, `float`, `int`

   - `$(list 1 2 3 4)` => [1, 2, 3, 4]
   - `$(cons 0 (list 1 2 3 4))` => [0, 1, 2, 3, 4]
         $(cons 0) => [0]
         $(cons) => []

   - `$(if <cond> <then> [<else>])`
   - `$(let (var1 value1 var2 value2 ...) <body-forms>)`
   
         $(let (x 2 y 5) (* $x $y)) => 10

     Note: (let) now assumes multiple body forms.

   - `$(fn (par1 par2 . rest_parameter) body)`
     Define a function

         $(let (x (fn (x) (+ $x 5))) (x 2)) => 7

     Things to note about functions definitions:

     Use `$foo` to reference the value of the variable foo in the function body:
     
         .echo $((fn (foo) $foo) 10) => 10
         .echo $((fn (foo) foo) 10) => foo

     The function body is treated as a template:
     
         .echo $((fn (. args) $(!lg $args fmt:"$name")) * xl>15)

         $(fn (x) (* $x 2))

   - `$(apply <fn> arg1 arg2 ... arglist)`
     Apply function to the given argument list, with any individual args
     prefixed
     
         $(apply ${+} (list 1 2 3 4 5)) => 15
         $(apply ${+} 6 (list 1 2 3 4 5)) => 21

   - `$(range <low> <high> [<step>])` range of numbers from low to high
     inclusive, with step defaulting to 1.
     
         .echo $(range 1 10) => 1 2 3 4 5 6 7 8 9 10
         .echo $(range 1 10 2) => 1 3 5 7 9

   - `$(concat arg1 arg2...)`
     Concatenate strings or lists; do not mix argument types.

   - `$(map <fn> <list>)`
   - `$(filter <predicate-fn> <list>)`
   - `$(sort [<fn>] <list>)`

   - `$(hash [<key> <value> ...])` create a dictionary
   - `$(hash-put <key> <value> ... <hash>)` add keys and values to hash
   - `$(hash-keys <hash>)` returns a list of the keys in a hash
   - `$(elt <key> <hash>)` get value of <hash>[<key>]
   - `$hash[key]` same as `$(elt key $hash)`
   - `$(elts <key> ... <hash>)` get list of hash values for keys
            Note: `(reverse <hash>)` will invert the hash, converting keys
                  to values and vice-versa.

   - `$(sort <list>)`
     `$(sort <comparator> <list>)`
            `<comparator>` must be a fn (a, b) that returns -1, 0, 1 if
            a < b, a == b, a > b

   - `$(flatten [<depth>] <list>)` Flattens nested lists inside list.

   - `$(scope [<hash>])`

     Returns a hash-like lookup object that contains the names bound in
     the current scope. As an example:

         $(let (x 55) $(elt x (scope))) => 55

     Scopes behave like hashes, but you may not be able to inspect
     all locally bound names using (hash-keys (scope)).

     If given an optional hash object, any names in that hash override
     bindings in the current scope:

         $(let (x 55) $(elt x (scope (hash x 32)))) => 32

   - `$(binding <scope|hash> [<forms>])`

     Evaluates <forms> with the given scope or hash. Using a simple
     hash will completely hide all bindings in enclosing scopes. If you
     want to retain existing bindings, use a scope:
     
         $(binding (hash x 20) $x) => 20
         $(let (y 30) $(binding (hash x 20) $y)) => ${y} (unbound y)
         $(let (y 30) $(binding (scope (hash x 20)) $y)) => 30

   - `$(do <forms>)`

     Evaluates <forms> in sequence and returns the value of the last.

   - `$(void)`

     Returns the null value.

   - `$(try <form> [<catch>])

     Evaluates and returns the value of `<form>`. If evaluating
     `<form>` raised an error, evaluates and returns the value of
     `<catch>`, or `(void)` if no *catch* form was provided. In the
     `<catch>` form, `$err!` will be bound to the error that was
     caught.
     

Unknown functions will be ignored:

     .echo $(foobar) => $(foobar)

### LearnDB access functions
   
   - `$(ldb <term> [<index>])`

     Retrieve the definition for `<term>[<index>]`. If the definition is
     a LearnDB redirect (see {foo}) or a LearnDB command invocation (do {cmd}),
     the redirect is followed, or the command is invoked. Definitions are
     automatically evaluated as templates.

     Returns a LearnDB entry object that converts to a string with
     (str <obj>) as:

         <term>[<index>/<count>] <definition>

     The definition may be examined as:

       1. `$(ldbent-term <e>)` => the term (after following redirects, etc.)
       2. `$(ldbent-index <e>)` => the index
       3. `$(ldbent-term-size <e>)` => the number of entries for the term
       4. `$(ldbent-text <e>)` => the definition.

   - `$(ldb-lookup "string query")`

     Takes a string query in the form `"<term>[<num>]"` and returns
     the definition. Otherwise identical in behavior to `ldb`.
       
   - `$(ldb-at <term> [<index>])`
   
     Retrieve the definition for `<term>[<index>]`, or the first
     definition if *index* is unspecified. The definition returned is
     a LearnDB entry object, but redirects and do { } commands are
     ignored, and the string is not treated as a template to be
     expanded, i.e. this is a raw LearnDB lookup.

   - `$(ldb-defs <term>)`

     Retrieves the list of definitions for `<term>`. Each definition
     is returned as a simple string, not as a LearnDB entry object.

   - `$(ldb-size <term>)`

     Returns the number of definitions for *term*, ignoring redirects.

   - `$(ldb-add <term> [<index>] <definition>)`

     Adds *definition* to *term*. If *index* is specified, the new definition
     will be inserted at that index. If no *index* is specified, the new
     definition will be appended as the last definition. An *index* of -1
     produces the same append behaviour as not specifying the index.

     Raises an error if used in PM.

   - `$(ldb-set! <term> <index> <definition>)`

     Replaces the existing definition at `term[index]` with the new
     definition. If no definition exists at term[index], does nothing.

     Raises an error if used in PM.
     
   - `$(ldb-rm! <term> <index>)`

     Deletes the definition at `term[index]`, or the whole term and all
     its definitions if an index of '*' is specified. Use with caution,
     there are no confirmation prompts.

     Raises an error if used in PM.

Multiple command-line expansions:
---------------------------------

!lg can use templates to format its output. These templates are also
expanded using the rules described above.

For instance, given the command

    !lg * win char=$(.echo HESk) stub:'$(!hs * HESk)'

The first expansion (before !lg runs):

    !lg * win char=HESk stub:'$(!hs * HESk)'

If !lg runs and finds no results, it will then evaluate the stub, viz.

    !hs * HESK


Suppressing command-line expansion:
-----------------------------------

Single-quoted strings are not expanded by default. This can be
used to defer costly subcommands until they're actually needed:

     !lg * stub:'No results, but look: $(!expensive-query)'

Although the default command-line expansion does not expand
single-quoted strings, !lg will still expand any string used as a
format, title, or stub.

Defining new functions
----------------------

Use !fn to define new functions:

    !fn double (x) $(* $x 2)
    .echo $(double 200) => 400

Functions may be recursive, but recursion depth is limited. !fn -ls
lists user-defined functions and !fn -rm deletes a function.