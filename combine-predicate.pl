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
# Currently, we are assuming the input format is sequnces of triplets of (word, the
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
binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

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
    $s =~ /^(.+)\/([^\/]+)\/([^\/]+)$/ or die $s;
    return ($1, $2, $3);
}

# TODO: Write the documentation about used heuristic rules.
sub iscombine {
    my $s = shift;
    my ($word, $pos, $pron) = wpp($s);
    print "word=$word\tpos=$pos\tpron=$pron\n";
    if($pos =~ /^(語尾|助動詞)$/) {
        return 1;
    } elsif(($word =~ /^(て|ば)$/) and ($pos =~ /^(助詞)$/)) {
        return 1;
    } elsif(($word =~ /^(な)$/) and ($pos =~ /^(形容詞)$/)) {
        return 1;
    } elsif(($word =~ /^(し|す|あ|い)$/) and ($pos =~ /^(動詞)$/)) {
        return 1;
    }
    return 0;
}

while(<STDIN>) {
    chomp;
    my @warr = split(/ /);
    my @harr = map { my ($w, $pr, $ps) = wpp($_); $w } @warr;
    my @carr = map { iscombine($_) } @warr;
    my @newarr = ($harr[0]);
    foreach my $i (1 .. $#warr) {
        if(($carr[$i] == 1) and ($carr[$i-1] == 1)) {
            $newarr[-1] .= $GLUE . $harr[$i];
        } else {
            push @newarr, $harr[$i];
        }
    }
    print "@newarr\n";
}
