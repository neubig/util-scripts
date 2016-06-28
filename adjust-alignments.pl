#!/usr/bin/perl

use strict;
use warnings;

use utf8;
use FindBin;
use lib $FindBin::Bin;
use Getopt::Long;
use List::Util qw(sum min max shuffle);
use Cwd qw(cwd);
use Levenshtein;
binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

my $SRC_TYPE = "lev";
my $TRG_TYPE = "lev";
GetOptions(
"src-type=s" => \$SRC_TYPE,
"trg-type=s" => \$SRC_TYPE,
);

if(@ARGV != 5) {
    print STDERR "Usage: $0 SRC_OLD TRG_OLD ALIGN SRC_NEW TRG_NEW\n";
    exit 1;
}

open FILE0, "<:utf8", $ARGV[0] or die "Couldn't open $ARGV[0]\n";
open FILE1, "<:utf8", $ARGV[1] or die "Couldn't open $ARGV[1]\n";
open FILE2, "<:utf8", $ARGV[2] or die "Couldn't open $ARGV[2]\n";
open FILE3, "<:utf8", $ARGV[3] or die "Couldn't open $ARGV[3]\n";
open FILE4, "<:utf8", $ARGV[4] or die "Couldn't open $ARGV[4]\n";

sub map_char {
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
    s/[\(（]/-lrb-/g;
    s/[\)）]/-rrb-/g;
    s/(``|'')/"/g;
    s/\&apos;/'/g;
    s/\&quot;/"/g;
    s/\&lt;/</g;
    s/\&gt;/>/g;
    s/([a-z])n 't/$1 n't/g;
    s/–/--/g;
    s/(`)/'/g;
    s/([^\\])\//$1\\\//g;
    s/[、，]/,/g;
    s/[。．]/./g;
    return lc($_);
}

sub map_lev {
    my ($in, $out) = @_;
    $in = normalize_en($in);
    $out = normalize_en($out);
    my @ia = split(/ /, $in);
    my @oa = split(/ /, $out);
    my ($hist, $score) = Levenshtein::distance($in, $out);
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
            @ierr = ();
            @oerr = ();
            $ret{$ipos++} = { $opos++ => 1 };
        } else {
            push @ierr, $ipos++ if $h ne 'i';
            push @oerr, $opos++ if $h ne 'd';
        }
    }
    foreach my $i (@ierr) {
        $ret{$i} = {};
        foreach my $o (@oerr) { $ret{$i}->{$o}++; }
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


my ($jo, $eo, $al, $jn, $en);
while(defined($jo = <FILE0>) and defined($eo = <FILE1>) and defined($al = <FILE2>) and defined($jn = <FILE3>) and defined($en = <FILE4>)) {
    chomp $jo; chomp $eo; chomp $al; chomp $jn; chomp $en;
    my %em = ($SRC_TYPE eq "lev") ? map_lev($eo, $en) : map_char($eo, $en);
    my %jm = ($SRC_TYPE eq "lev") ? map_lev($jn, $jo) : map_char($jn, $jo);
    my %am;
    s/ +$//g;
    for(split(/ /, $al)) {
        my ($ja, $ea) = split(/-/);
        $am{$ja} = {} if not $am{$ja};
        $am{$ja}->{$ea}++;
    }
    my %jam = combine_map(\%jm, \%am);
    my %jaem = combine_map(\%jam, \%em);
    print_map(\%jaem);
}
