# The LearnDB

The LearnDB is a user-maintained database of content accessible to
users of ##crawl and ##crawl-dev on freenode IRC. This is a brief
description of the commands available to query and update the LearnDB.

The LearnDB is organized into *terms* (also called *pages*). Each term
may have one or more entries. For user convenience, entries may link
to other entries.


## Querying the LearnDB

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

## Adding to the LearnDB

Use !learn add to add entries to the LearnDB. If no term exists,
!learn add will create the term and add the entry. If an existing
term is found, !learn add will append the entry to the list of
existing entries for that term.

When adding terms, separate words with underscores, or quote the term
if it contains embedded spaces.

    <user> !learn add cow A domesticated ungulate.
    <Sequell> cow[1/1]: A domesticated ungulate.
    <user> !learn add cow Has four legs.
    <Sequell> cow[2/2]: Has four legs.
    <user> !learn add superior_cow More cow than cow
    <Sequell> superior cow[1/1]: More cow than cow
    <user> ?? superior cow
    <Sequell> superior cow[1/1]: More cow than cow
    <user> !learn add "superior cow" Considerably more
    <Sequell> superior cow[2/2]: Considerably more

Quoting a term does not imply that the term will be created verbatim:
quoted terms will still have leading and trailing spaces removed and
the term normalized. Quoting is merely a convenience for entering
embedded spaces.

    <user> !learn add " extra    spaces    lost " quoting doesn't mean exact
    <Sequell> extra spaces lost[1/1]: quoting doesn't mean exact

Quoting is *required* if you want the term to start and end with quotes:

    <user> !learn add '"double quotes"' outer quotes required here
    <Sequell> "double quotes"[1/1]: outer quotes required here

If a term has existing entries, you may insert a new entry at a
particular index by specifying the index:

    <user> !learn add cow[1] Vocalization: "Mooo!"
    <Sequell> cow[1/3]: Vocalization: "Mooo!"

When inserting entries, any existing entry with the same or larger
index is renumbered one higher to accommodate the new entry.

## Updating entries in the LearnDB

Use !learn set to replace the content of an existing entry in the LearnDB:

    !learn set TERM[NUM] New text

!learn set acts like !learn add if there is no existing definition.

Use !learn edit to modify portions of entries in the LearnDB. Identify
the entry you're editing with term[index] and use a search and replace
expression in the form s/<search>/<replacement>/.

    <user> !learn edit cow[1] s/Mooo!/Moo?/
    <Sequell> cow[1/4]: Vocalization: "Moo?"

Searches are regular expressions, so regex metacharacters such as + and ?
in the search must be escaped:

    <user> !learn edit cow[1] s/\?/!/
    <Sequell> cow[1/4]: Vocalization: "Moo!"

Sequell uses [the RE2 regex engine](https://code.google.com/p/re2/wiki/Syntax)

Regular expressions are case-insensitive by default, but can be made
case-sensitive using the flag I

### Edit Flags

Sequell recognises these regex flags for !learn edit:

| Flag | Description                              |
|------|------------------------------------------|
| I    | Case-sensitive search                    |
| g    | Global replace (replace all occurrences) |

You may also use embedded regex flags such as (?-i).

## Removing entries from the LearnDB

Use !learn del to remove entries from the LearnDB. Specify an entry by
term and index. You may only remove one entry at a time.

    <user> !learn del cow[1]
    <Sequell> Deleted cow[1/4]: Vocalization: "Moo!"

## Moving entries

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

You may swap entries as:

    !learn swap A[x] B[y]

and swap terms as:

    !learn swap A B

## Quoting

Quoted strings are accepted as a convenience when entering long terms
with embedded spaces, where it would be awkward to replace those
spaces with underscores. Quoted strings are interpreted only for the
LearnDB manipulation commands, not when querying the DB.

Quoted strings are still normalized for embedded spaces and stripped
of leading and trailing spaces.

## Searching

You may search the LearnDB with
[regular expressions](https://code.google.com/p/re2/wiki/Syntax) using `?/`:

    ?/ <search regex: search in both terms and definitions>
    ?/< <search regex: search terms only>
    ?/> <search regex: search definitions only>

If your `?/` search starts with `<` or `>`, use a space to separate the
search from the `?/`.

## LearnDB command aliases

Some LearnDB commands may be aliases to different names, you may use
any alias as convenient.

1. !learn query == !learn q
2. !learn add == !learn insert == !learn a
3. !learn set == !learn s
4. !learn edit == !learn e
5. !learn move == !learn mv
6. !learn delete == !learn del == !learn rm

## Links

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

An alternative to `do {<command>}` is `$(<command>)`, but
`$(<command>)` will trigger sub-command behaviour, which may be
conspicuously different from regular command behaviour (particularly
for !lg / !lm).

## Query Forms

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
3. $channel: The channel, or "msg" for private messages.

Sequell will also expand standard
[Command-Line Expansions](commandline.md) in entries.

Sequell's template language has [direct access to the
LearnDB](commandline.md#learndb-access-functions); when automating
actions, prefer the LearnDB functions to subcommands.

Behaviour
---------

This feature is experimental, inspired by
[Rodney](http://alt.org/nethack/Rodney/).

The entries for the :beh: term define text that Sequell will look for
someone to say and then respond to. The format for :beh: entries is:

    <TEXT> ::: <ACTION> [ ::: <NEXT-STEP> ]

1. *TEXT* defines the input pattern that Sequell must match for the :beh:
   action to trigger.
2. The *ACTION* template defines what Sequell says in response to the input.
3. The *NEXT-STEP* template (optional) defines how Sequell proceeds after a *TEXT* match.

Every line of text anyone says or emotes on IRC feeds into Sequell's
behaviour evaluator as follows:

1. User says "xyz" on IRC.
2. Sequell takes each :beh: rule in turn and attempts to match it to "xyz".
3. If the rule matches:
  * Sequell evaluates the *NEXT-STEP* template, if any. If the next
    step evaluates to "break", Sequell skips further behaviour
    evaluation, even if the current rule produces no output. If the
    next step is "last", Sequell will not evaluate any further
    behaviour rules, OR any further commands. If the next step is
    "continue", Sequell will evaluate the next behaviour rule even if
    the current rule produces output.
  * Sequell evaluates the action. If the action evaluates to a non-empty
    text, Sequell responds with the text and does nothing further for that
    command (unless the next step was "continue", or "break").

For instance adding this behaviour:

    !learn add :beh: Hi! ::: Hello, $nick. Welcome to ${channel}!

Will provoke Sequell to greet any visitor to the channel who says "Hi!"

    <user> Hi!
    <Sequell> Hello, user. Welcome to ##crawl!

The match *TEXT* is a [regular expression](https://code.google.com/p/re2/wiki/Syntax)
with optional convenience syntax to capture sections of text by name:

    !learn add :beh: Give $person a hug ::: /me hugs $person.
    <user> Give rutabaga a hug
    * Sequell hugs rutabaga.

*TEXT* always matches the entire input line. You can indicate that
TEXT should not be anchored to the end of the line using >>> at the end,
and not anchored to the beginning using <<< at the beginning. <<< and >>>
may be used together.

When <<< is used, an implicit capture of $before is created for the
text before the match. >>> implicitly captures $after with the text
after the match:

    !learn add :beh: /me visits >>> ::: /me also visits $after
    * user visits the Lair.
    * Sequell also visits the Lair.

<<< and >>> are just a convenience; you may instead use standard regular
expression syntax, using the `(?P<name>pattern)` capture syntax.

    !learn add :beh: /me visits (?P<place>.*) ::: /me also visits $place

Capturing variables normally match single words only. You can request
a capture to span words by preceding the capture name with * (notice
the need to escape the regex metacharacter ? in the example)

    !learn add :beh: Is there $*balm in Gilead\? ::: Why, yes, there is $balm
    <user> Is there milk and honey in Gilead?
    <Sequell> Why, yes, there is milk and honey

Optionally, you may define additional conditions that must be
satisfied before a behaviour is evaluated as `{{<check>:<value>}}`. As
an example:

    !learn add :beh: {{channel:##crawl-dev}} Hi! ::: Shh!

`{{ }}` conditions are very limited (strict case-insensitive equality
only), and may also be evaluated as (if) or other conditionals on the
right side of the :::, but using `{{ }}` is much faster and should be
preferred where it is sufficient.

Available conditions:
1. nick
2. channel (is 'msg' for private messaging)
3. body (the entire message)
4. emoted (is '1' if this is an IRC emote, viz. a user doing /me something).

*NEXT-STEP* is optional, and controls how Sequell reacts to the given
input. The *NEXT-STEP* template is expanded using the standard
template expansion. After expansion, Sequell lowercases and removes
leading and trailing whitespace, then compares the next step to the
known behaviour steps.

### Behaviour evaluation table

Sequell reacts to text on IRC in this sequence:

1. Behaviours (any text prefixed with `\\` ignores behaviours)
2. LearnDB direct queries, viz. ??TERM
3. LearnDB indirect queries, viz. TERM??
4. Commands

In general, Sequell responds to the first matching item: if a user
says something that triggers a behaviour, Sequell will not then try to
look up the same thing in the LearnDB or treat it as a command. If a
user LearnDB query like X?? is matched, Sequell will not proceed to
evaluate the same query as a command.

Here's a table summarising how behaviours are evaluated, with and
without *NEXT-STEP*. Behaviours are evaluated in sequence, with
malformed behaviours ignored.

| *TEXT* matched | *ACTION* not empty | *NEXT-STEP*  | What happens                                                                       |
|----------------|--------------------|----------|------------------------------------------------------------------------------------|
| No             | -                  | -        | Nothing happens for this behaviour, next behaviour is evaluated                    |
| Yes            | No                 | (none)   | Nothing happens for this behaviour, next behaviour is evaluated                    |
| Yes            | Yes                | (none)   | Says or emotes the action, no further behaviours or commands are evaluated.        |
| Yes            | -                  | break    | Says the action if not empty, then skips other behaviours and proceeds with LearnDB lookup and normal command evaluation.                        |
| Yes            | -                  | last     | Says the action if not empty, then does no other behaviours or command evaluation. |
| Yes            | -                  | continue | Says the action if not empty, then evaluates the next behaviour                    |

For instance, to nag LearnDB users to use PM every now and then, but
still respond to the query:

    !learn add :beh: \?\?>>> ::: $(if (and (/= $channel msg) (not (rand 10))) "/msg $bot your queries, ${nick}!") ::: break

To ignore a LearnDB query:

    !learn add :beh: \?\?\s*secret\s* :::  ::: last

## LearnDB Limitations

Terms may not contain the ` ` (space), `[` and `]` characters. Terms
are case-insensitive and case-preserving, but case-insensitive
matching for non-ASCII characters is undefined. Don't assume
case-insensitive matching for non-ASCII text.


## ACLs

Access to Henzell's LearnDB, nick-mappings, keywords, and commands may
be restricted by ACLs. ACLs are meta-LearnDB entries that can be used
to restrict access to certain operations.

An ACL is a LearnDB term of the form: :acl:[PERMISSION], with a
corresponding entry specifying users and/or channels that have that
permission.

A *permission* is of the form [prefix]:[name] where *prefix* indicates the
type of permission, usually one of `db`, `cmd`, `kw`, or `nick`, and *name*
indicates the specific thing the user is trying to access. A *permission* may
use a trailing `*` as a wildcard. If a non-wildcard permission must end with a
trailing `*`, it may be suffixed with a trailing `.`.

An ACL entry is at minimum a list of IRC nicks and/or channels that the ACL
must be restricted to, in the form:

    entry = term*;
    term = atom | deny;
    atom = nick | channel | nick-group | channel-group;
    deny = "DENY:(" atom* ")" | "DENY:" atom;
    nick = <any IRC nick, not starting with # or @> | "*" | "+authenticated";
    channel = "#" <channel-name> | "#:pm" | "#*";
    nick-group = "@" <group-name>;
    channel-group = "#@" <group-name>;

As an example, if we want to limit access to LearnDB behaviour entries (:beh:),
to authenticated users (users who have registered and authenticated with
NickServ), we may define an ACL as:

    !learn set :acl:db::beh: +authenticated

Thereafter, Sequell will refuse attempts to modify :beh: by unauthenticated
users.


ACLs may also specify explicit lists of nicks:

    !learn set :acl:db::beh: nicka nickb nickc

If an explicit list of nicks is used, only users in that list have the
permission in question. Explicit nicks always require authentication with
services, since unauthenticated nicks are trivial to impersonate.

Wildcard ACLs are handy when you want to manage *all* access to the LearnDB
or the relevant commands. For instance, to forbid nick remapping in private
messages, use:

    !learn set :acl:nick:* DENY:#:pm

### ACL selection

When a user invokes a command that requires a permission, say "nick:foo",
Sequell picks the *longest* LearnDB term of the form ":acl:\*" that matches
"nick:foo". So if there were ACLs labeled :acl:nick:foo and :acl:nick:\*,
Sequell would prefer :acl:nick:foo in this case, since it is the longest
permission match.

Only *one* ACL is ever evaluated. If there are no matching ACLs, the user is
granted the permission, i.e. missing ACLs fail open. The only exception to this
is the `proxy` permission.

### Groups

To reduce duplication in ACLs, ACLs may refer to groups. A group named X is the
list of users or channels defined in :group:X. As an example, if I want to
give users oak, ash, and beech permissions to nick:tree, I might do:

     !learn set :group:tree oak ash beech
     !learn set :acl:nick:tree @tree

Groups may be groups of user nicks or channels. For instance, if I'd like
nick mappings to be changeable only on ##crawl or ##crawl-dev, I might do:

     !learn set :group:crawl-channels ##crawl ##crawl-dev
     !learn set :acl:nick:* #@crawl-channels

Bear in mind that ACLs are not inherited. If you have an ACL on
:acl:nick:\* and another on :acl:nick:foo, attempts to access nick:foo
will completely ignore restrictions set in :acl:nick:\*.

Groups are not themselves full ACLs, they are simple lists of nicks or
channels. Groups may recursively refer to other groups as @group.

### Linking ACLs

If you have multiple identical ACLs, you may use LearnDB redirects as
`see {:acl:other}` to link to the master ACL.


### Permissions

This is the list of permissions Sequell uses. To apply an ACL to any
permission, you may add a LearnDB ACL entry of the form :acl:PERM.

| Permission  | Description                                     |
|-------------|-------------------------------------------------|
| db:[TERM]   | LearnDB add/edit/delete for TERM                |
| nick:[NICK] | !nick changes for NICK                          |
| cmd:[CMD]   | !cmd changes for the command named CMD          |
| kw:[KW]     | !kw changes for the keyword KW                  |
| proxy       | Proxying permission (see [Proxying](#proxying)) |

### Proxying

Other IRC bots may proxy commands to Sequell on behalf of their channels. If
an IRC bot is relaying commands on behalf of an end-user, and wants Sequell to
treat that command as if the end-user issued it directly to Sequell, it may
use the [!RELAY meta-command](commandline.md#relaying-commands-to-sequell).
However, Sequell will still decline relayed commands such as !tell, UNLESS the
relaying bot has the `proxy` permission.

To give a bot the permission to proxy, add it to :acl:proxy. For instance:

    !learn set :acl:proxy UltraBot

If the relaying bot is in :acl:proxy and identified to NickServ, Sequell trusts
the bot and treats relayed commands as if they were directly issued to Sequell
by the end-user specified in the -nick option, on the channel specified in the
-channel option.

## API

See [the Sequell LearnDB API](api.md#learndb).