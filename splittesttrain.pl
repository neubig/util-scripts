#!/usr/bin/perl

binmode STDIN, ":utf8";

my $fraction = $ARGV[0];
open TEST, ">:utf8", $ARGV[1] or die $!;
if($ARGV[2]) {
    open TRAIN, ">:utf8", $ARGV[2] or die $!;
}

while(<STDIN>) {
    if($i++ % $fraction) {
        if($ARGV[2]) {
            print TRAIN $_;
        }
    }
    else {
        print TEST $_;
    }
}
