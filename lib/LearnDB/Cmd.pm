package LearnDB::Cmd;

use strict;
use warnings;

use LearnDB;
use Henzell::Authorize;

sub insert_entry {
  my ($term, $num, $text) = @_;
  my $original_term = $term;
  LearnDB::check_term_length($term);
  LearnDB::check_text_length($text);
  $term = LearnDB::cleanse_term($term);
  Henzell::Authorize::cmd_permit("db:$term");
  $num = -1 if ($num || '') eq '$';
  $num = $LearnDB::DB->add($term, $text, $num);
  return LearnDB::read_entry($original_term, $num);
}

sub del_entry {
  my $term = LearnDB::normalize_term(shift);
  Henzell::Authorize::cmd_permit("db:$term");
  my $entry_num = LearnDB::normalize_index($term, shift(), 'query');
  $LearnDB::DB->remove($term, $entry_num);
}

sub replace_entry
{
  my $term = LearnDB::normalize_term(shift);
  Henzell::Authorize::cmd_permit("db:$term");
  my $entry_num = LearnDB::normalize_index($term, shift());
  my $new_text = shift;
  $LearnDB::DB->update_value($term, $entry_num, $new_text);
  LearnDB::read_entry($term, $entry_num)
}

sub move_entry($$$;$) {
  my ($src, $snum, $dst, $dnum) = @_;
  LearnDB::check_term_length($src);
  LearnDB::check_term_length($dst);
  my $osrc = $src;
  $_ = LearnDB::normalize_term($_) for $src, $dst;
  if (!$snum) {
    LearnDB::check_entry_exists($src, 1);
    if (lc($src) ne lc($dst) && LearnDB::term_exists($dst)) {
      die "$dst exists, cannot overwrite it.\n";
    }
    Henzell::Authorize::cmd_permit("db:$src");
    Henzell::Authorize::cmd_permit("db:$dst");
    LearnDB::rename_entry($src, $dst);
    return "$osrc -> " . LearnDB::read_entry($dst, 1);
  }
  else {
    LearnDB::check_entry_exists($src, $snum);
    Henzell::Authorize::cmd_permit("db:$src");
    Henzell::Authorize::cmd_permit("db:$dst");
    my $src_entry = LearnDB::read_entry($src, $snum, 'just-the-entry');
    $snum = LearnDB::normalize_index($src, $snum, 'query');
    del_entry($src, $snum);
    return "$osrc\[$snum] -> " .
      insert_entry($dst, $dnum || -1, $src_entry);
  }
}

sub swap_terms {
  my ($term1, $term2) = @_;
  $_ = LearnDB::normalize_term($_) for $term1, $term2;
  Henzell::Authorize::cmd_permit("db:$term1");
  Henzell::Authorize::cmd_permit("db:$term2");
  $LearnDB::DB->swap_terms($term1, $term2)
}

sub swap_entries {
  my ($term1, $num1, $term2, $num2) = @_;
  $_ = LearnDB::normalize_term($_) for ($term1, $term2);
  Henzell::Authorize::cmd_permit("db:$term1");
  Henzell::Authorize::cmd_permit("db:$term2");
  $num1 = LearnDB::normalize_index($term1, $num1);
  $num2 = LearnDB::normalize_index($term2, $num2);

  my $def1 = $LearnDB::DB->definition($term1, $num1);
  my $def2 = $LearnDB::DB->definition($term2, $num2);
  $LearnDB::DB->update_value($term1, $num1, $def2);
  $LearnDB::DB->update_value($term2, $num2, $def1);
  return 1;
}

1
