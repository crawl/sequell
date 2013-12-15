use strict;
use warnings;

use Test::More;
use lib 'lib';
use File::Path;
use utf8;

BEGIN {
  $ENV{LEARNDB} = 'tmp/test.db';
  unlink $ENV{LEARNDB};
};

File::Path::make_path('tmp');

$ENV{IRC_NICK_AUTHENTICATED} = 'y';
$ENV{HENZELL_SQL_QUERIES} = 'y';
$ENV{RUBYOPT} = '-rubygems -Isrc';
$ENV{PERL_UNICODE} = 'AS';
$ENV{HENZELL_ROOT} = '.';
$ENV{HENZELL_ALL_COMMANDS} = 'y';

use Henzell::ReactorService;
use Henzell::IRCTestStub;
use Henzell::CommandService;
use Henzell::Bus;
use LearnDB;

my $channel = '##crawl';
my $nick = 'greensnark';
my $rc = 'rc/sequell.rc';
my $irc = Henzell::IRCTestStub->new(channel => $channel);
my $bus = Henzell::Bus->new;
my $cmd = Henzell::CommandService->new(irc => $irc,
                                       config => $rc,
                                       bus => $bus);
my $ldb = Henzell::ReactorService->new(executor => $cmd,
                                       irc => $irc,
                                       bus => $bus);
$irc->configure_services(services => [$ldb]);

is(irc('??cow'), "I don't have a page labeled cow in my learndb.");
is(irc('!learn add cow MOOOOOO'), 'cow[1/1]: MOOOOOO');
is(irc('??cow'), "cow[1/1]: MOOOOOO");

irc('!learn add pow see {cow}');
is(irc('??pow'), "cow[1/1]: MOOOOOO");

irc('!learn add cow cowcowcow');
is(irc('??pow[2]'), "cow[2/2]: cowcowcow");
is(irc('??pow[-1]'), "cow[2/2]: cowcowcow");

irc('!learn add cow How now');
irc('!learn add cszo cßo');
is(irc('??cszo'), "cszo[1/1]: cßo");
is(irc('??pow[-1]'), "cow[3/3]: How now");

irc('!learn set cow[-1] How now brown cow');
is(irc('??pow[-1]'), "cow[3/3]: How now brown cow");

is(irc('!learn set radon An element'), 'radon[1/1]: An element');
is(irc('!learn set radon A radioactive element'),
   'radon[1/1]: A radioactive element');
is(irc('!learn set radon[5] Rn'),
   'radon[2/2]: Rn');
is(irc('!learn set radon[2] RADON'),
   'radon[2/2]: RADON');
is(irc('!learn set radon[-1] ?'),
   'radon[2/2]: ?');
is(irc('!learn set radon[$] ???'),
   'radon[2/2]: ???');
is(irc('!learn set puma[$] PUMA'), 'puma[1/1]: PUMA');

irc('!learn add !help:!foo Hahahahaha');
is(irc('!help !foo'), "!foo: Hahahahaha");
like(irc('!help !bar'), qr/No help for !bar/);

beh('Hi! ::: Hello, $nick. Welcome to ${channel}!', sub {
  is(irc('Hi!'), "Hello, greensnark. Welcome to ##crawl!")
});

beh('Give $person a hug ::: /me hugs $person.', sub {
  is(irc('Give rutabaga a hug'), "/me hugs rutabaga.")
});

beh('/me visits >>> ::: /me also visits $after', sub {
  is(emote('visits the Lair'), "/me also visits the Lair")
});

beh('/me visits (?P<place>.*) ::: /me also visits $place', sub {
  is(emote('visits the Lair'), "/me also visits the Lair")
});

beh('Is there $*balm in Gilead\? ::: Why, yes, there is $balm', sub {
  is(irc('Is there milk and honey in Gilead?'),
     "Why, yes, there is milk and honey")
});

beh('r\?\?>>> ::: $(!learn q $after)', sub {
  is(irc('r??cow'), "cow[1/3]: MOOOOOO")
});

beh('.echo Hi! ::: Hola ::: continue',
    '.echo Hi! ::: Eeek! ::: break', sub {
  is(irc('.echo Hi!'), "Hola\nEeek!\nHi!");
});

beh('.echo Hi! ::: Hola ::: last',
    '.echo Hi! ::: Eeek! ::: break', sub {
  is(irc('.echo Hi!'), "Hola");
});

beh('.echo Hi! ::: Eeek! ::: break',
    '.echo Hi! ::: Hola ::: last', sub {
      is(irc('.echo Hi!'), "Eeek!\nHi!");
});

beh('\?\?\s*secret\s* :::  ::: last', sub {
  is(irc('??secret'), "");
  is(irc('\\\\??secret'), "I don't have a page labeled secret in my learndb.");
});

beh('!tell $bot >>> ::: Flee, ${nick}! ::: last', sub {
  is(irc('!tell Sequell Hi'), "Flee, greensnark!");
  like(irc('!tell greensnark Hi'), qr/OK, .*greensnark/);
});

irc('!cmd !yak .echo Hi');
is(irc('!yak'), "Hi");
irc('!cmd -rm !yak');

is(irc('.echo $(do 0)'), '0');

done_testing();

sub irc {
  my $command = shift();
  $irc->tick();
  $irc->said({ channel => $channel,
               body => $command,
               verbatim => $command,
               who => $nick });
  my $out = $irc->output() || '';
  $out =~ s/\s+$//;
  $out
}

sub emote {
  my $command = shift();
  $irc->emoted({ channel => $channel,
                 body => $command,
                 who => $nick });
  my $out = $irc->output() || '';
  $out =~ s/\s+$//;
  $out
}

sub beh {
  my @beh = @_;
  my $test = pop @beh;
  LearnDB::del_term(':beh:');
  irc("!learn add :beh: $_") for @beh;
  $test->();
}
