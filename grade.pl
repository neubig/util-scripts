#!/usr/bin/perl

use strict;
push @INC, "/home/neubig/usr/bin";
require "levenshtein.pl";
use List::Util qw(max min);

sub width {
    $_ = shift;
    my $ret = 0;
    for(split(//)) {
        $ret += ((/[０-９]/ or /\p{InKatakana}/ or /\p{InHiragana}/ or /\p{InCJKSymbolsAndPunctuation}/ or /\p{InKatakanaPhoneticExtensions}/ or /\p{InCJKUnifiedIdeographs}/)?2:1);
    }
    return $ret;
}

sub pad {
    my ($s, $l) = @_;
    return $s . (' ' x ($l-width($s)));
}

use strict;
binmode STDOUT, ":utf8";
open REF, "<:utf8", $ARGV[0];
open TEST, "<:utf8", $ARGV[1];

my ($reflen, $testlen);
my %scores = ();
my($ref, $test, $sent, $sentacc);
while($ref = <REF> and $test = <TEST>) {
    chomp $ref;
    chomp $test;
    
    # get the arrays
    my @ra = split(/ /, $ref);
    $reflen += @ra;
    my @ta = split(/ /, $test);
    $testlen += @ta;

    # do levenshtein distance if the scores aren't equal
    my ($hist, $score);
    if ($ref eq $test) {
        $sentacc++;
        for (@ra) { $hist .= 'e'; }
        $score = 0;
    } else {
        ($hist, $score) = levenshtein($ref, $test);
    }
    $sent++;

    my @ha = split(//, $hist);
    my ($rd, $td, $hd, $h, $r, $t, $l);
    while(@ha) {
        $h = shift(@ha);
        $scores{$h}++;
        if($h eq 'e' or $h eq 's') {
            $r = shift(@ra);
            $t = shift(@ta);
        } elsif ($h eq 'i') {
            $r = '';
            $t = shift(@ta);
        } elsif ($h eq 'd') {
            $r = shift(@ra);
            $t = '';
        } else { die "bad history value $h"; }
        # find the length
        $l = max(width($r), width($t)) + 1;
        $rd .= pad($r, $l);
        $td .= pad($t, $l);
        $hd .= pad($h, $l);
    }
    print "$rd\n$td\n$hd\n\n";
}

my $total = 0;
for (values %scores) { $total += $_; }
foreach my $k (keys %scores) {
    print "$k: $scores{$k} (".$scores{$k}/$total*100 . "%)\n";
}
my $wer = ($scores{'s'}+$scores{'i'}+$scores{'d'})/$reflen*100;
my $prec = $scores{'e'}/$testlen*100;
my $rec = $scores{'e'}/$reflen*100;
my $fmeas = (2*$prec*$rec)/($prec+$rec);
$sentacc = $sentacc/$sent*100;
printf ("WER: %.2f%%\nPrec: %.2f%%\nRec: %.2f%%\nF-meas: %.2f%%\nSent: %.2f%%\n", $wer, $prec, $rec, $fmeas, $sentacc);

