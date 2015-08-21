use strict;
use warnings;

use Test::More;
use File::Path;

use lib 'lib';
use Henzell::SQLLearnDB;

File::Path::make_path('tmp');
unlink('tmp/test.db');

my $db = Henzell::SQLLearnDB->new('tmp/test.db');

sub exercise_db {
  my $db = shift;
  ok($db, "Opened LearnDB file");
  ok($db->term_count() == 0, "DB is empty (terms)");
  ok($db->definition_count() == 0, "DB is empty (definitions)");
  ok($db->add('cow', 'eats grass') == 1, "Add term");
  ok($db->has_term('cow'), "Added term exists");
  ok($db->definition_count('cow') == 1, "Added term values exist");
  ok($db->term_count('cow') == 1, "Term count matches expected");
  ok(($db->definitions('cow'))[0] eq 'eats grass', 'Value is as expected');

  ok($db->add('cow', 'Mooo!', 1) == 1, "Insert term");
  ok($db->definition_count('cow') == 2, "Term count matches expected");
  ok(($db->definitions('cow'))[0] eq 'Mooo!', 'Value is as expected');
  ok(($db->definitions('cow'))[1] eq 'eats grass', 'Value is as expected');

  $db->update_value('cow', 1, 'Moo?');
  ok($db->definition('cow', 1) eq 'Moo?', "Updated value is correct");
  ok($db->definition('cow', 0) eq 'Moo?', '0 index is same as 1');
  ok($db->definition('cow', 2) eq 'eats grass', "Un-updated value is correct");
  ok($db->definition('cow') eq 'Moo?', 'Default index is 1');
  ok(!$db->definition('cow', 50), 'Out of bounds');
  ok(!$db->definition('cow', -1), 'Out of bounds');

  $db->remove('cow', 1);
  ok($db->definition_count('cow') == 1, 'Term count after delete is correct');
  ok($db->definition('cow', 1) eq 'eats grass',
     'Can retrieve by index after delete');

  $db->add('yak', 'YAK');
  $db->add('yak', 'Shaggy');
  $db->add('yak', 'Awesome');
  $db->add('yak', 'Hooved', 3);
  ok($db->definition_count('yak') == 4);
  ok($db->definition('yak', 4) eq 'Awesome', "Insert in middle worked");
  ok($db->definition('yak', 3) eq 'Hooved', "Insert in middle worked");

  $db->update_term('yak', 'bison');
  ok($db->definition_count('bison') == 4, "Rename works");
  ok($db->definition_count('yak') == 0, "Rename works");
  $db->update_term('bison', 'yak');

  $db->remove('yak', 3);
  ok($db->definition_count('yak') == 3, "Delete in middle works");
  ok($db->definition('yak', 1) eq 'YAK', "Delete in middle works");
  ok($db->definition('yak', 2) eq 'Shaggy', "Delete in middle works");
  ok($db->definition('yak', 3) eq 'Awesome', "Delete in middle works");
  $db->remove('yak');
  ok(!$db->has_term('yak'), 'Delete full term works');
  ok(!$db->definition_count('yak'), 'Delete full term works');

  $db->add('meow', 'cat');
  $db->add('meow', 'mrow?');
  $db->add('meow', 'pow', -1);
  ok($db->definition_at('meow', 3) eq 'pow', "Add with -1 appends");
  ok($db->definition_count('meow') == 3);
  $db->remove('meow', 1);
  $db->remove('meow', 1);
  $db->remove('meow', 1);
  ok($db->definition_count('meow') == 0, "Test clean multidelete");
  ok(!$db->has_term('meow'), "Test clean multidelete");
}

exercise_db($db);
done_testing();
