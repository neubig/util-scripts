#!/usr/bin/perl

# This is a script to grade word error rates according to edit distance
if(@ARGV != 2) {
    print STDERR "$0 REF TEST\n";
    exit(1);
}

binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

use utf8;
use strict;
use warnings;
use List::Util qw(max min);
use Cwd qw(cwd abs_path);
use FindBin;
use lib $FindBin::Bin;

use Levenshtein;

my $PRINT_INLINE = 1;

sub width {
    $_ = shift;
    my $ret = 0;
    for(split(//)) {
        $ret += ((/\p{InKatakana}/ or /\p{InHiragana}/ or /\p{InCJKSymbolsAndPunctuation}/ or /\p{InKatakanaPhoneticExtensions}/ or /\p{InCJKUnifiedIdeographs}/)?2:1);
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
my %scores = qw(s 0 i 0 d 0 e 0);
my($ref, $test, $sent, $sentacc) = (0, 0, 0, 0);
while(defined($ref = <REF>) and defined($test = <TEST>)) {
    chomp $ref;
    chomp $test;
    $ref =~ s/^ *//g; $ref =~ s/ *$//g;
    $test =~ s/^ *//g; $test =~ s/ *$//g;

    # get the arrays
    my @ra = split(/ +/, $ref);
    $reflen += @ra;
    my @ta = split(/ +/, $test);
    $testlen += @ta;

    # do levenshtein distance if the scores aren't equal
    my ($hist, $score);
    if ($ref eq $test) {
        $sentacc++;
        for (@ra) { $hist .= 'e'; }
        $score = 0;
    } else {
        ($hist, $score) = Levenshtein::distance($ref, $test);
    }
    $sent++;

    my @ha = split(//, $hist);
    for(@ha) { $scores{$_}++; }
    my ($rd, $td, $hd, $h, $r, $t, $l);
    if(not $PRINT_INLINE) {
        while(@ha) {
            $h = shift(@ha);
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
        die "non-empty ra=@ra or ta=@ta\n" if(@ra or @ta);
    } else {
        for(Levenshtein::divide($ref, $test, $hist)) {
            my ($stra, $strb) = split(/\t/);
            print ((($stra eq $strb) ? "O" : "X")."\t$_\n");
        }
        print "\n";
    }
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
