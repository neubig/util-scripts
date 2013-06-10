#!/usr/bin/perl

#
# What's this?
# ------------
#
# Combine segmented predicates in Japanese sentences into manageable
# units for ease of statistical machine translation tasks such as word
# alignment, rule extraction and other subsequent processes.
#
# Usage and Data Format
# ---------------------
#
# Currently, we are assuming the input format is sequences of triplets of (word, the
# part-of-speech, and the reading of the word). Each triplet should be delimitted by
# slash "/".
#
# Here is the sample input and output of this script.
#
#    $ echo "これ/代名詞/これ は/助詞/は ペン/名詞/ぺん で/助動詞/で あ/動詞/あ る/語尾/る" | ./combine-predicate.pl
#    word=これ       pos=代名詞      pron=これ
#    word=は pos=助詞        pron=は
#    word=ペン       pos=名詞        pron=ぺん
#    word=で pos=助動詞      pron=で
#    word=あ pos=動詞        pron=あ
#    word=る pos=語尾        pron=る
#    これ は ペン である
#
#
# This kinds of the input data are used in the output format of KyTea
# (http://www.phontron.com/kytea/) For example,
#
#    $ echo "これはペンである" | kytea | ./combine-predicate.pl
#    これ は ペン である
#

use strict;
use warnings;
use utf8;
use Getopt::Long;
use List::Util qw(sum min max shuffle);
binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

my $VERB = 0;
GetOptions(
"verb" => \$VERB,
);


my $GLUE = "";
if (@ARGV eq 1) {
    $GLUE = $ARGV[0];
} elsif (@ARGV > 1) {
    print STDERR "Usage: $0 [GLUE]\n";
    exit 1;
}

# Split each of the triplet into three things.
#
# E.g., "これ/代名詞/これ" => ("これ", "代名詞", "これ"),
# "ペン/名詞/ぺん" => ("ペン", "名詞", "ぺん")
#
sub wpp {
    my $s = shift;
    # print STDERR "$s\n";
    $s =~ /^(.+)\/([^\/]+)\/([^\/]+)$/ or die $s;
    return ($1, $2, $3);
}

# TODO: Write the documentation about used heuristic rules.
sub iscombine {
    my $s = shift;
    my ($word, $pos, $pron) = wpp($s);
    if($VERB and ($pos =~ /^動詞$/)) {
        return 1;
    } elsif($pos =~ /^(語尾|助動詞)$/) {
        return 1;
    } elsif(($word =~ /^(て|ば)$/) and ($pos =~ /^(助詞)$/)) {
        return 1;
    } elsif(($word =~ /^(な)$/) and ($pos =~ /^(形容詞)$/)) {
        return 1;
    } elsif(($word =~ /^(さ|し|す|あ|い)$/) and ($pos =~ /^(動詞)$/)) {
        return 1;
    }
    return 0;
}

# Combine predicates, and return the sequence of words.
#
# If there are consecutive words that fire the bits,
# they will be combined into a single word.
#
# For example,
# $harr = ["これ", "は", "ペン", "で", "あ", "る"]
# $carr = [0, 0, 0, 1, 1, 1]
# => ["これ", "は", "ペン", "である"]
#
# Note that the words ["で", "あ", "る"] were merged into
# "である".
sub combine {
  my ($harr, $carr) = @_;
  my @newarr = ($$harr[0]);
  foreach my $i (1 .. $#$harr) {
    if (($$carr[$i] == 1) and ($$carr[$i-1] == 1)) {
      $newarr[-1] .= $GLUE . $$harr[$i];
    } else {
      push @newarr, $$harr[$i];
    }
  }
  return \@newarr;
}

while(<STDIN>) {
    chomp;
    # print "$_\n";
    s/\\ /　/g;
    my @warr = split(/ +/);
    my @harr = map { my ($w, $pr, $ps) = wpp($_); $w } @warr;
    my @carr = map { iscombine($_) } @warr;
    print "@{combine(\@harr, \@carr)}\n";
}
