The LearnDB
===========

The LearnDB is a user-maintained database of content accessible to
users of ##crawl and ##crawl-dev on FreeNode IRC. This is a brief
description of the command available to query and update the LearnDB.

The LearnDB is organized into *terms* (also called *pages*). Each term
may have one or more entries. For user convenience, some entries
may be links to other entries.


Querying the LearnDB
--------------------

Use ?? to query the LearnDB:

    ?? <term> [entry-index]

For instance:
    
    <user> ??zot[2]
    <Sequell> zot[2/6]: Mind the gaps in your resistances while ...

If the entry index is omitted, the start entry index of 1 is assumed.
An entry index of 0 is considered equivalent to 1.

Terms with lots of entries may also be queried using negative indices to
index from the end of the list of entries. As an example:

    <user> ??zot[-1]
    <Sequell> zot[6/6]: Before DCSS 0.1.3, ...
    <user> ??zot[-2]
    <Sequell> zot[5/6]: You could see an orb of fire, ...

An alternative to ??<term> is the !learn query form:

    <user> !learn query zot[-1]
    <Sequell> zot[6/6]: Before DCSS 0.1.3, ...

?? is not identical to !learn query; see [Query Forms](#query-forms)
for more information.

When querying, don't use negative indices that go beyond the first
entry (in the case of the example, -7 or beyond). The behaviour in
such cases is unspecified and may change in the future.

The behaviour for positive indexes that go past the last entry is
likewise unspecified: some LearnDB manipulation commands will treat
out-of-bounds positive entries as equivalent to the last index, while
others will just report an error, and this behaviour may change in the
future.

Adding to the LearnDB
---------------------

Use !learn add to add entries to the LearnDB. If no term exists,
!learn add will create the term and add the entry. If an existing
term is found, !learn add will append the entry to the list of
existing entries for that term.

When adding terms, separate words with underscores; do not use spaces
to separate words in the term:

    <user> !learn add cow A domesticated ungulate.
    <Sequell> cow[1/1]: A domesticated ungulate.
    <user> !learn add cow Has four legs.
    <Sequell> cow[2/2]: Has four legs.
    <user> !learn add superior_cow More cow than cow
    <Sequell> superior cow[1/1]: More cow than cow
    <user> ?? superior cow
    <Sequell> superior cow[1/1]: More cow than cow

If a term has existing entries, you may insert a new entry at a
particular index by specifying the index:

    <user> !learn add cow[1] Vocalization: "Mooo!"
    <Sequell> cow[1/3]: Vocalization: "Mooo!"

When inserting entries, any existing entry with the same or larger
index is renumbered one higher to accommodate the new entry.

Updating entries in the LearnDB
-------------------------------

Use !learn edit to edit entries in the LearnDB. Identify the entry you're
editing with term[index] and use a search and replace expression in the
form s/<search>/<replacement>/.

    <user> !learn edit cow[1] s/Mooo!/Moo?/
    <Sequell> cow[1/4]: Vocalization: "Moo?"

Searches are regular expressions, so regex metacharacters such as + and ?
in the search must be escaped:

    <user> !learn edit cow[1] s/\?/!/
    <Sequell> cow[1/4]: Vocalization: "Moo!"

Sequell uses [the RE2 regex engine](https://code.google.com/p/re2/wiki/Syntax)

Regular expressions are case-insensitive by default, but can be made
case-sensitive using the flag I

### Flags

Sequell recognises these regex flags for !learn edit:

| Flag | Description                              |
|------|------------------------------------------|
| I    | Case-sensitive search                    |
| g    | Global replace (replace all occurrences) |

You may also use embedded regex flags such as (?-i).

Removing entries from the LearnDB
---------------------------------

Use !learn del to remove entries from the LearnDB. Specify an entry by
term and index. You may only remove one entry at a time.

    <user> !learn del cow[1]
    <Sequell> Deleted cow[1/4]: Vocalization: "Moo!"

Moving entries
--------------

You may move entries using the general form:

    !learn move A[x] B[y]
    
This is equivalent to the two command sequence:

    !learn del A[x]
    !learn add B[y] <old content of A[x]>

You may omit the index on the destination term:

    !learn move A[x] B
    =>
    !learn del A[x]
    !learn add B <old content of A[x]>

You may rename terms as:

    !learn move A B

Renaming a term will fail if the destination term already exists.

You may swap terms as:

    !learn swap A[x] B[y]

LearnDB command aliases
-----------------------

Some LearnDB commands may be aliases to different names, you may use
any alias as convenient.

1. !learn query == !learn q
2. !learn add == !learn insert == !learn a
3. !learn edit == !learn e
4. !learn move == !learn mv
5. !learn delete == !learn del == !learn rm

Query Forms
-----------

There are three ways to query the LearnDB:

1. ??term
2. term??
3. !learn query term

??term is the standard query. Sequell will report errors if a user
requests a nonexistent term with ??term, and will generally indicate
the entry number and the count of entries when queried with ??term:

    <user> ??zot
    <Sequell> zot[1/6]: The final area of the game, ...

term?? is an indirect query. Sequell will silently ignore the query
if the LearnDB does not contain the term. If Sequell finds the term in
the LearnDB, it will report the entry, but will skip the summary of the
entry number and the count of entries.

    <user> zot??
    <Sequell> The final area of the game, ...

!learn query is the canonical query: it prevents Sequell from
modifying the entry for display in any way.

    <user> !learn query zot
    <Sequell> zot[1/6]: The final area of the game, ...

?? and !learn query differ in how they interpret
[Text Templates](#text-templates).

Text Templates
--------------

When queried with ??x and x??, Sequell expands entries as follows:

1. Any $variable that Sequell recognises will be replaced with its value.
2. Any $variable that Sequell does not recognise will be echoed.
3. If the entry is prefixed with ": " (colon space, without the quotes),
   Sequell will skip the term[index/count]: prefix when displaying the entry.
   Note that this is the default behaviour when queried with the form x??

Sequell recognizes these variables:

1. $nick/$user: The nick interacting with Sequell.
2. $bot: Sequell's own nick ("Sequell").
3. $channel: The channel.

Sequell will also expand standard
[Command-Line Expansions](listgame.md#command-line-expansion) in entries.

Sequell's template language has [direct access to the
LearnDB](commandline.md#learndb-access-functions); when automating
actions, prefer the LearnDB functions to subcommands.

Behaviour
---------

This feature is experimental, inspired by
[Rodney](http://alt.org/nethack/Rodney/).

The entries for the :beh: term define text that Sequell will look for
someone to say and then respond to. The format for :beh: entries is:

    <TEXT> ::: <ACTION>

For instance adding this behaviour:

    !learn add :beh: Hi! ::: Hello, $nick. Welcome to $channel!

Will provoke Sequell to greet any visitor to the channel who says "Hi!"

    <user> Hi!
    <Sequell> Hello, user. Welcome to ##crawl!

The TEXT that Sequell matches against is intentionally limited to
reduce the chances of excessive bot spam. You are restricted to simple
matches of text. You may define very limited capturing patterns:

    !learn add :beh: Give $person a hug ::: /me hugs $person.
    <user> Give rutabaga a hug
    * Sequell hugs rutabaga.

The TEXT normally matches the entire input line. You can indicate that
TEXT should not be anchored to the end of the line using >>> at the end,
and not anchored to the beginning using <<< at the beginning. <<< and >>>
may be used together.

When <<< is used, an implicit capture of $before is created for the
text before the match. >>> implicitly captures $after with the text
after the match:

    !learn add :beh: /me visits >>> :: /me also visits $after
    * user visits the Lair.
    * Sequell also visits the Lair.

Capturing variables normally match single words only. You can request
a capture to span words by preceding the capture name with *:

    !learn add :beh: Is there $*balm in Gilead? ::: Why, yes, there is $balm
    <user> Is there milk and honey in Gilead?
    <Sequell> Why, yes, there is milk and honey

Links
-----

Entries may link to other entries using the `see {term[index]}` format:

    !learn add kine see {cow}
    <user> ??kine
    <Sequell> cow[1/2]: A domesticated ungulate.
    <user> kine??
    <Sequell> A domesticated ungulate.

`!learn query` ignores redirects.

LearnDB Entries may run bot commands using `do {<command>}`:

    !learn add mylastwin do {!lg . win}

`see {<command>}` also works as an alternative to `do {<command>}`,
but the `do` form is preferred for commands, since `see {<command>}` will
only run `<command>` if there is no LearnDB entry for `<command>`.

An alternative to `do {<command>}` is `$(<command>)`, but `$(<command>)` will
trigger sub-command behaviour, which can be conspicuously different from
regular command behaviour (particularly for !lg / !lm).

Limitations
-----------

Terms may not contain the ` ` (space), `[` and `]` characters. Terms
are case-insensitive and case-preserving, but case-insensitive
matching for non-ASCII characters is unpredictable. Do not rely on
case-folding for anything outside the ASCII character set.
