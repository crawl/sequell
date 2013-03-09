#! /usr/bin/env perl
#
# Generates the henzell.sql file defining Henzell's database schema.

use strict;
use warnings;

use Henzell::Schema;
use Getopt::Long;

my $OUTFILE = 'henzell-schema.sql';
my $INDEXFILE = 'henzell-indexes.sql';

my $schema = Henzell::Schema->new(tables_only => 1);
open my $outf, '>', $OUTFILE or die "Can't write $OUTFILE: $!\n";
print $outf $schema->sql();
close $outf;

my $indexes = Henzell::Schema->new(indexes_only => 1);
open my $indexf, '>', $INDEXFILE or die "Can't write $INDEXFILE: $!\n";
print $indexf $indexes->sql();
close $indexf;

print STDERR "Wrote schema to $OUTFILE, indexes to $INDEXFILE\n";
