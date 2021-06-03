Sequell
-------

Sequell is the stats IRC bot for #crawl on Libera IRC.

Sequell is the successor to the original #crawl Henzell which at one
point shared the same code. There are still many references to Henzell
in the source and configuration.

Dependencies
------------

* Go 1.3 or better from http://golang.org/ or installed via your
  package manager.

  Your [GOPATH environment variable](https://golang.org/doc/code.html)
  must be correctly set, and $GOPATH/bin must be in your PATH for the
  `seqdb` tool.

* PostgreSQL 9

  1. Install PostgreSQL, create a database 'sequell' and a user
     'sequell', and give the user access to the database with password
     'sequell'.

  2. In the 'sequell' database, install the PostgreSQL citext and orafce
     extensions by running (as an admin user):
         CREATE EXTENSION citext;
         CREATE EXTENSION orafce;

     citext is available as part of Postgres contrib; orafce is available at:
         [https://github.com/orafce/orafce](https://github.com/orafce/orafce)

     Sequell needs the CITEXT extension for case-insensitive
     comparison and grouping and the orafce extension for the median
     aggregate function. You may choose to skip the orafce extension
     if you do not need the median() aggregate function.

     You can use the seqdb tool to create the database and extensions
     if you run it as a Postgres admin user:

     Build seqdb from the Sequell root directory:

          $ make

     Then create the database:

          $ seqdb createdb --admin postgres --adminpassword xyzzy

     Depending on what authentication mode you're using for Postgres, you
     may need to run seqdb as the postgres Unix user (if using ident auth),
     and/or override the host and port you're connecting on.

     If you're connecting to Postgres using Unix sockets, specify the
     Unix socket directory as the --host option:

          $ seqdb --host /var/run/postgresql createdb

     Note that you still have to install the orafce and citext
     extensions for Postgres system-wide before you can create a
     database that uses these extensions. `seqdb createdb` merely
     automates the process of creating the database and `sequell`
     database user and creating the extensions in the database; it
     cannot install the extensions system-wide.

  2. Set up the database:

     Build Sequell's DB ops tool using `make` (this requires Go 1.3+):

          $ make

     Create the database tables in the schema:

          $ seqdb create-tables

     Populate the database: first fetch the server logs, then load them:

          $ seqdb fetch && seqdb load

     Create indexes and constraints on the database after loading logs:

          $ seqdb create-indexes

     You can change the database seqdb connects to, and how it connects.
     Run `seqdb` for an overview.

* RE2

  1. Install RE2 using the package manager on your system (libre2-dev
     on the Debian family).

* Ruby

  Sequell requires ruby 1.9 or better. You may need to install
  rubygems and the ruby headers (ruby-dev), depending on your system.

* Perl

  Perl >= 5.14


Sequell wants Perl modules for IRC, YAML parsing, DB connectivity,
etc. In addition the SQL query commands require several Ruby gems. To
install Sequell's dependencies, use:

    # ./scripts/install-libs

You can also install the Perl and Ruby dependencies independently:

    # ./scripts/install-perl-modules
    # gem install bundler && bundle install


Configuring Sequell
-------------------

Sequell has three primary functions:

1. Providing a repository for user-maintained content (the LearnDB).
2. Storing records of all games on public serves and making them available to
   query.
3. Serving a playlist of games enqueued for FooTV. This is one half of
   the configuration for FooTV. The FooTV service must separately be
   configured to connect to Sequell's playlist server.

Sequell also provides additional utility commands.

You configure Sequell by supplying an rc/sequell.rc in the *directory from
which you run Sequell*. You can alternatively specify the rc filename
as a command-line option with:

    perl sequell.pl --rc=some/path/to/myweirdrc


Running Sequell queries without connecting to IRC
-------------------------------------------------

If you want to test new commands or run `!lg` queries on a local Sequell
database without involving IRC, you can use the `scripts/runcmd.pl` script for
an interactive Sequell REPL with no IRC strings attached. It's a good idea to
run it via rlwrap for command-line editing and history support:

    $ rlwrap ./scripts/runcmd.pl
    Sequell command runner
    > !lg *
    7941444. foo the Warrior (L19 MfGl of Okawaru), mangled by a naga ritualist (a +3 dagger of venom) on Snake:4 (snake_hunt) on 2017-10-22 18:04:42, with 217416 points after 31169 turns and 0:53:26.

runcmd.pl assumes a default IRC nick of `anon`, and a default IRC channel of
`#crawl`, for commands that expect to see a nick/channel. You may override
these defaults with the NICK/CHANNEL environment variables.

    $ NICK=won CHANNEL='#crawl-dev' rlwrap ./scripts/runcmd.pl
    > .echo $nick in $channel
    Sequell command runner
    won in #crawl-dev
