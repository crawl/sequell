#! /usr/bin/env perl
#
# Generates the henzell.sql file defining Henzell's database schema.

use strict;
use warnings;

use Henzell::Schema;

my $OUTFILE = 'henzell-schema.sql';

my $schema = Henzell::Schema->new();
open my $outf, '>', $OUTFILE or die "Can't write $OUTFILE: $!\n";
print $outf $schema->sql();
close $outf;

print STDERR "Wrote schema to $OUTFILE\n";
