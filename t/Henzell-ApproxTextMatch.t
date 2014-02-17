use strict;
use warnings;

use Test::More;
use lib 'lib';

use Henzell::ApproxTextMatch;

my $matcher = Henzell::ApproxTextMatch->new('coc', [ 'cow', 'cows', 'kine', 'death magic' ]);

is_deeply([$matcher->fuzz_levenshtein('coc')], ['coc', 'cow'], 'Fuzz atom Levenshtein');
is_deeply([$matcher->fuzz_stemming('cows')], ['cow', 'cows'], 'Stemming fuzz');
ok($matcher->atom_in_dictionary('tips'));
ok($matcher->term_in_db('cows'));
ok($matcher->term_in_db('death magic'));
done_testing();
