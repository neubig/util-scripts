#!/usr/bin/perl

use Text::Iconv;

if(@ARGV != 2) {
    print STDERR "Usage: $0 FROM TO\n";
    exit 1;
}

$| = 1;
my $converter = Text::Iconv->new($ARGV[0], $ARGV[1]) or die;
while(<STDIN>) {
    my $converted = $converter->convert($_) or die $!;
    print $converted;
}
