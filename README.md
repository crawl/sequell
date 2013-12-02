Sequell
-------

Sequell is the announcement and stats IRC bot for ##crawl on Freenode IRC.

Sequell is the successor to the original ##crawl Henzell which at one
point shared the same code. There are still many references to Henzell
in the source and configuration.

Dependencies
------------

* PostgreSQL 9

  1. Install PostgreSQL, create a database 'henzell' and a user
     'henzell', and give the user access to the database with password
     'henzell'. Note that the name is 'henzell', not 'sequell'.
  
  2. In the 'henzell' database, install the PostgreSQL citext and orafce
     extensions by running (as an admin user):
        CREATE EXTENSION citext;
        CREATE EXTENSION orafce;
  
     citext is available as part of Postgres contrib; orafce is available at:
        http://orafce.projects.postgresql.org/
  
     Sequell needs the CITEXT extension for case-insensitive comparison
     and grouping and the orafce extension for the median aggregate function.
  
  2. Set up the database schema as:
  
     Generate the schema:
     perl schema-gen.pl
  
     Create the tables:
     psql -U henzell henzell < henzell-schema.sql

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

   # ./install-libs

You can also install the Perl and Ruby dependencies independently:

   # ./install-perl-modules
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
