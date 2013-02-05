#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use List::Util qw(sum min max shuffle);
use Getopt::Long;
binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

if(@ARGV != 2) {
    print STDERR "Usage: fakesgm.pl src/ref tar\n";
    exit 1;
}

print "<".$ARGV[0]."set setid=\"test2006\" srclang=\"any\" trglang=\"$ARGV[1]\">
<DOC docid=\"test2006\"".(($ARGV[1] eq "ref")?" sysid=\"ref\"":" sysid=\"src\"").">\n";

my $sent = 1;
while(<STDIN>) {
    chomp;
    print "<seg id=\"".$sent++."\"> $_ </seg>\n";
}

print "</DOC>\n</".$ARGV[0]."set>\n";
