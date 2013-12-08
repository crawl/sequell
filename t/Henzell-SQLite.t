use strict;
use warnings;

use Test::More;
use lib 'lib';

use Henzell::SQLite;
use File::Path;

File::Path::make_path('tmp');
unlink('tmp/sqlite.db');

my $db = Henzell::SQLite->new('tmp/sqlite.db');
ok($db->do('CREATE TABLE cow (name STRING)'),
   "Execute DDL");
ok($db->has_table('cow'), "Created table exists");
ok(!$db->has_table('other'), "Table detect works");
$db->begin_work;
$db->exec('INSERT INTO cow (name) VALUES (?)', 'Grenada');
$db->commit;
ok($db->query_val('SELECT name FROM cow LIMIT 1') eq 'Grenada',
   'Query inserted value');
ok($db->query_val('SELECT name FROM cow WHERE name = ?', 'Grenada') eq
     'Grenada', 'Query with query_val');

done_testing();
