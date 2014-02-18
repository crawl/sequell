package Henzell::ApproxTextMatch;

use Text::Levenshtein::Damerau qw//;
use Text::Levenshtein::Damerau::XS;
use Lingua::Stem qw/stem :caching/;
use Data::Dumper;

my $DICTIONARY;

sub new {
  my ($cls, $term, $db_terms, $dictionary_file, %misc) = @_;
  stem_caching({ -level => 2 });
  bless { term => normalize_term($term),
          db_terms => [map(normalize_term($_), @$db_terms)],
          dictionary_file => ($dictionary_file || '/usr/share/dict/words'),
          %misc
        }, $cls
}

sub normalize_term {
  my $term = shift;
  $term =~ tr/_/ /;
  $term =~ s/ +/ /g;
  s/^\s+//, s/\s+$// for $term;
  lc($term)
}

sub edit_distance {
  my ($self, $term) = @_;
  return 1 if length($term) < 8 || $term !~ /^[a-z]+$/i;
  2
}

sub filter_matching {
  my $self = shift;
  my %seen;
  grep(!$seen{$_}++ && $self->term_in_db($_), @_)
}

sub approx_matches {
  my $self = shift;
  my @permutations =
    $self->permute($self->fuzz_words($self->term_words()));
  my @found = $self->filter_matching(@permutations);
  if (!@found) {
    @found = $self->filter_matching(
      map($self->simple_levenshtein($_), @permutations));
  }
  @found
}

sub term_in_db {
  my ($self, $term) = @_;
  $self->db_term_dictionary()->{$term}
}

sub db_terms {
  shift()->{db_terms}
}

sub db_term_dictionary {
  my $self = shift;
  $self->{db_term_dictionary} ||= { map(($_ => 1),
                                        @{$self->db_terms()}) }
}

sub db_atoms {
  my $self = shift();
  $self->{db_atoms} ||= $self->word_atoms(@{$self->db_terms()})
}

sub db_atom_dictionary {
  my $self = shift;
  $self->{db_atom_dictionary} ||= { map(($_ => 1), @{$self->db_atoms()}) }
}

sub dictionary {
  my $self = shift;
  unless ($DICTIONARY) {
    my $dict = { };
    $DICTIONARY = $dict;
    if (-f $self->{dictionary_file}) {
      my @words = do { local (@ARGV) = $self->{dictionary_file};
                       <> };
      for my $word (@words) {
        chomp $word;
        $word = lc $word;
        $dict->{$word} = 1;
      }
    }
  }
  $DICTIONARY
}

sub atom_in_dictionary {
  my ($self, $atom) = @_;
  my $dict = $self->dictionary();
  $dict->{$atom} || $dict->{stem($atom)->[0]}
}

sub atom_in_db {
  my ($self, $atom) = @_;
  $self->db_atom_dictionary()->{$atom}
}

sub atom_is_known {
  my ($self, $atom) = @_;
  $self->atom_in_dictionary($atom) || $self->atom_in_db($atom)
}

sub word_atoms {
  my $self = shift();
  my %seen_atom;
  [ sort(grep(!$seen_atom{$_}++, map($self->split_term($_), @_))) ]
}

sub term_words {
  my $self = shift;
  $self->split_term($self->{term})
}

sub fuzz_words {
  my ($self, @words) = @_;
  map($self->fuzz_atom($_), @words)
}

sub fuzz_atom {
  my ($self, $atom) = @_;
  return +[$atom] unless length($atom) >= 3 && $atom =~ /^[a-z]+$/i;

  # Two fuzz strategies: Levenshtein distance and stemming.
  # Levenshtein distance is *not* applied for dictionary words.
  my %seen;
  my @levenshtein = grep(!$seen{$_}++, $self->fuzz_levenshtein($atom));
  %seen = ();
  +[ grep(!$seen{$_}++, @levenshtein,
          map($self->fuzz_stemming($_), @levenshtein)) ]
}

sub best_levenshtein_matches {
  my ($self, $term, $match_list, $distance) = @_;
  my @matches;
  my $term_length = length($term);
  my $best_distance = $distance || $self->edit_distance($term);
  for my $match (@$match_list) {
    if (abs(length($match) - $term_length) <= $best_distance) {
      my $distance = Text::Levenshtein::Damerau::edistance($match, $term);
      if ($distance <= $best_distance) {
        @matches = () if $distance < $best_distance;
        push @matches, $match;
        $best_distance = $distance;
      }
    }
  }
  @matches
}

sub simple_levenshtein {
  my ($self, $term) = @_;
  ($term, $self->best_levenshtein_matches($term, $self->db_terms()))
}

sub fuzz_levenshtein {
  my ($self, $atom) = @_;
  return ($atom) if $self->atom_is_known($atom);
  ($atom, $self->best_levenshtein_matches($atom, $self->db_atoms()))
}

sub fuzz_stemming {
  my ($self, $atom) = @_;
  $atom = stem($atom)->[0];
  my @matches;
  for my $db_atom (@{$self->db_atoms()}) {
    push @matches, $db_atom if stem($db_atom)->[0] eq $atom;
  }
  @matches
}

sub split_term {
  my ($self, $term) = @_;
  split(' ', normalize_term($term))
}

sub permute {
  my ($self, @permutable_words) = @_;
  my $current = shift @permutable_words;
  return @$current unless @permutable_words;
  my @inferior_permutations = $self->permute(@permutable_words);

  my @permutations;
  for my $atom (@$current) {
    for my $inferior_permute (@inferior_permutations) {
      push @permutations, "$atom $inferior_permute";
    }
  }
  my %seen;
  grep(!$seen{$_}++, @permutations)
}

1
