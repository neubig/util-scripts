#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use Text::Iconv;
use Getopt::Long;
use List::Util qw(sum min max shuffle);
binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

my $ARG = "";
GetOptions(
"arg=s" => \$ARG,
);

if(@ARGV != 2) {
    print STDERR "Usage: $0 FROM TO\n";
    exit 1;
}

$| = 1;
my $converter = Text::Iconv->new($ARGV[0], $ARGV[1]) or die;
while(<STDIN>) {
    print $converter->convert($_);
}
