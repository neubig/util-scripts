#!/usr/bin/perl

use strict;
use warnings;

use utf8;
use Getopt::Long;
use List::Util qw(sum min max shuffle);
use Cwd qw(cwd);
require ("".cwd()."/levenshtein.pl");
binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

if(@ARGV != 5) {
    print STDERR "Usage: $0 JA_OLD EN_OLD ALIGN JA_NEW EN_NEW\n";
    exit 1;
}

open FILE0, "<:utf8", $ARGV[0] or die "Couldn't open $ARGV[0]\n";
open FILE1, "<:utf8", $ARGV[1] or die "Couldn't open $ARGV[1]\n";
open FILE2, "<:utf8", $ARGV[2] or die "Couldn't open $ARGV[2]\n";
open FILE3, "<:utf8", $ARGV[3] or die "Couldn't open $ARGV[3]\n";
open FILE4, "<:utf8", $ARGV[4] or die "Couldn't open $ARGV[4]\n";

my ($jo, $eo, $al, $jn, $en);

sub map_ja {
    my ($in, $out) = @_;
    my @ia = split(/ /, $in);
    my @oa = split(/ /, $out);
    my (@iw, @ow);
    foreach my $i (0 .. $#ia) { push @iw, $i for(0 .. length($ia[$i])-1); }
    foreach my $i (0 .. $#oa) { push @ow, $i for(0 .. length($oa[$i])-1); }
    # print "@iw\n@ow\n";
    die "$in\n$out\n" if(@iw != @ow);
    # Create the map
    my %ret;
    foreach my $i (0 .. $#iw) {
        $ret{$iw[$i]} = {} if not $ret{$iw[$i]};
        $ret{$iw[$i]}->{$ow[$i]}++;
    }
    return %ret;
}

sub normalize_en {
    $_ = shift;
    s/\(/-lrb-/g;
    s/\)/-rrb-/g;
    s/(``|'')/"/g;
    s/n 't/ n't/g;
    s/–/--/g;
    s/(`)/'/g;
    s/([^\\])\//$1\\\//g;
    return $_;
}

sub map_en {
    my ($in, $out) = @_;
    $in = normalize_en($in);
    $out = normalize_en($out);
    my ($hist, $score) = levenshtein($in, $out);
    my @hists = split(//, $hist);
    my (@ierr, @oerr);
    my ($ipos, $opos) = (0, 0);
    my %ret;
    while(@hists) {
        my $h = shift(@hists);
        if($h eq 'e') {
            foreach my $i (@ierr) {
                $ret{$i} = {};
                foreach my $o (@oerr) { $ret{$i}->{$o}++; }
            }
            $ret{$ipos++} = { $opos++ => 1 };
        } else {
            push @ierr, $ipos++ if $h ne 'i';
            push @oerr, $opos++ if $h ne 'd';
        }
    }
    # die "$in\n$out\n" if($in ne $out);
    return %ret;
}

sub print_map {
    my $map = shift;
    my @arr;
    # print join(" ", keys %{$map})."\n";
    foreach my $i (sort { $a <=> $b } keys %{$map}) {
        foreach my $j (sort { $a <=> $b } keys %{$map->{$i}}) {
            push @arr, "$i-$j";
        }
    }
    print "@arr\n";
}

sub combine_map {
    my ($in, $out) = @_;
    my %ret;
    foreach my $i ( keys %$in ) {
        foreach my $j ( keys %{$in->{$i}} ) {
            foreach my $k ( keys %{$out->{$j}} ) {
                $ret{$i} = {} if not $ret{$i};
                $ret{$i}->{$k}++;
            }
        }
    }
    return %ret;
}

while(($jo = <FILE0>) and ($eo = <FILE1>) and ($al = <FILE2>) and ($jn = <FILE3>) and ($en = <FILE4>)) {
    chomp $jo; chomp $eo; chomp $al; chomp $jn; chomp $en;
    my %em = map_en($eo, $en);
    my %jm = map_ja($jn, $jo); 
    my %am;
    for(split(/ /, $al)) {
        my ($ja, $ea) = split(/-/);
        $am{$ja} = {} if not $am{$ja};
        $am{$ja}->{$ea}++;
    }
    my %jam = combine_map(\%jm, \%am);
    my %jaem = combine_map(\%jam, \%em);
    print_map(\%jaem);
}
