use strict;
use warnings;

package Henzell::ServerConfig;

use base 'Exporter';
use YAML::Any qw/LoadFile/;

use Henzell::SourceServer;

my $SERVER_CONFIG_FILE = 'config/sources.yml';
my $SERVERCFG = LoadFile($SERVER_CONFIG_FILE);

my @SERVERS = map(Henzell::SourceServer->new($_),
                  @{$SERVERCFG->{sources}});

sub servers {
  @SERVERS
}

sub server_logfiles {
  map($_->logfiles(), servers())
}

sub server_milestones {
  map($_->milestones(), servers())
}

sub source_hostname {
  my $source = shift;
  $$SERVERCFG{sources}{$source}
}

sub server_abbreviations {
  %{$$SERVERCFG{sources}}
}

1
