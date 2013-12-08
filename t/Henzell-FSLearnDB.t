use strict;
use warnings;

use Test::More;
use lib 'lib';
use Henzell::FSLearnDB;
use File::Path;

my $db = 'tmp/learndb';

File::Path::rmtree($db);

db_add('yak', 1, 'How now');
db_add('yak', 2, 'brown yak');
db_add('cow', 1, 'MOooooo!');

my $fsdb = Henzell::FSLearnDB->new($db);
ok($fsdb->definition('yak') eq 'How now');
ok($fsdb->definition('yak', 2) eq 'brown yak');
ok(($fsdb->definitions('yak'))[1] eq 'brown yak');
ok(($fsdb->definitions('yak'))[0] eq 'How now');

my @terms;
$fsdb->each_term(sub { push @terms, shift() });
ok(@terms == 2);
ok(grep($_ eq 'yak', @terms));
ok(grep($_ eq 'cow', @terms));
done_testing();

sub db_add {
  my ($term, $num, $entry) = @_;
  my $dir = "$db/$term";
  File::Path::make_path($dir);
  my $file = "$dir/$num";
  open my $outf, '>', $file or die "Can't write $file: $!\n";
  print $outf $entry;
  close $outf;
}
