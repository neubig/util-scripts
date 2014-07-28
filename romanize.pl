#!/usr/bin/perl

use strict;
use utf8;
use FileHandle;
use Getopt::Long;
use List::Util qw(sum min max shuffle);
binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

if(@ARGV != 0) {
    print STDERR "Usage: $0\n";
    exit 1;
}

our %Map = (
    "あ", "A",
    "い", "I",
    "う", "U",
    "え", "E",
    "お", "O",
    "か", "KA",
    "き", "KI",
    "く", "KU",
    "け", "KE",
    "こ", "KO",
    "さ", "SA",
    "し", "SHI",
    "す", "SU",
    "せ", "SE",
    "そ", "SO",
    "た", "TA",
    "ち", "CHI",
    "つ", "TSU",
    "て", "TE",
    "と", "TO",
    "な", "NA",
    "に", "NI",
    "ぬ", "NU",
    "ね", "NE",
    "の", "NO",
    "は", "HA",
    "ひ", "HI",
    "ふ", "FU",
    "へ", "HE",
    "ほ", "HO",
    "ま", "MA",
    "み", "MI",
    "む", "MU",
    "め", "ME",
    "も", "MO",
    "や", "YA",
    "ゆ", "YU",
    "よ", "YO",
    "ら", "RA",
    "り", "RI",
    "る", "RU",
    "れ", "RE",
    "ろ", "RO",
    "わ", "WA",
    "ゐ", "I",
    "ゑ", "E",
    "を", "O",
    "ん", "N",
    "ぁ", "A",
    "ぃ", "I",
    "ぅ", "U",
    "ぇ", "E",
    "ぉ", "O",
    "が", "GA",
    "ぎ", "GI",
    "ぐ", "GU",
    "げ", "GE",
    "ご", "GO",
    "ざ", "ZA",
    "じ", "JI",
    "ず", "ZU",
    "ぜ", "ZE",
    "ぞ", "ZO",
    "だ", "DA",
    "ぢ", "JI",
    "づ", "ZU",
    "で", "DE",
    "ど", "DO",
    "ば", "BA",
    "び", "BI",
    "ぶ", "BU",
    "べ", "BE",
    "ぼ", "BO",
    "ぱ", "PA",
    "ぴ", "PI",
    "ぷ", "PU",
    "ぺ", "PE",
    "ぽ", "PO",
    "きゃ", "KYA",
    "きゅ", "KYU",
    "きょ", "KYO",
    "しゃ", "SHA",
    "しゅ", "SHU",
    "しょ", "SHO",
    "ちゃ", "CHA",
    "ちゅ", "CHU",
    "ちょ", "CHO",
    "ちぇ", "CHE",
    "にゃ", "NYA",
    "にゅ", "NYU",
    "にょ", "NYO",
    "ひゃ", "HYA",
    "ひゅ", "HYU",
    "ひょ", "HYO",
    "みゃ", "MYA",
    "みゅ", "MYU",
    "みょ", "MYO",
    "りゃ", "RYA",
    "りゅ", "RYU",
    "りょ", "RYO",
    "ぎゃ", "GYA",
    "ぎゅ", "GYU",
    "ぎょ", "GYO",
    "じゃ", "JA",
    "じゅ", "JU",
    "じょ", "JO",
    "びゃ", "BYA",
    "びゅ", "BYU",
    "びょ", "BYO",
    "ぴゃ", "PYA",
    "ぴゅ", "PYU",
    "ぴょ", "PYO",
    "ふぇ", "FE",
    "ふぁ", "FA",
    "ふぉ", "FO",
    "ふぃ", "FI",
    "じぇ", "JE",
    "じぁ", "JA",
    "じぉ", "JO",
    "っど", "D",
    "っと", "T",
);

sub new {
    my($class, %opt) = @_;
    bless { %opt }, $class;
}

sub _hepburn_for {
    my($string, $index) = @_;

    my($hepburn, $char);
    if ($index + 1 < length $string) {
        $char    = substr $string, $index, 2;
        $hepburn = $Map{$char};
    }
    if (!$hepburn && $index < length $string) {
        $char    = substr $string, $index, 1;
        $hepburn = $Map{$char};
    }

    return { char => $char, hepburn => $hepburn };
}

sub romanize {
    my($string) = @_;
    return $string if not $string =~ /(\p{InHiragana}|\p{InKatakana})/g;

    unless (utf8::is_utf8($string)) {
        die "romanize(string): should be UTF-8 flagged string";
    }

    $string =~ tr/ァ-ン/ぁ-ん/;

    my $output;
    my $last_hepburn;
    my $last_char;
    my $i = 0;

    while ($i < length $string) {
        my $hr = _hepburn_for($string, $i);

        # １．撥音 ヘボン式ではB ・M ・P の前に N の代わりに M をおく
        if ($hr->{char} eq 'ん') {
            my $next = _hepburn_for($string, $i + 1);
            $hr->{hepburn} = $next->{hepburn} && $next->{hepburn} =~ /^[BMP]/
                ? 'M' : 'N';
        }

        # ２．促音 子音を重ねて示す
        elsif ($hr->{char} eq 'っ') {
            my $next = _hepburn_for($string, $i + 1);

            # チ（CH I）、チャ（CHA）、チュ（CHU）、チョ（CHO）音に限り、その前に T を加える。
            if ($next->{hepburn}) {
                $hr->{hepburn} = $next->{hepburn} =~ /^CH/
                    ? 'T' : substr($next->{hepburn}, 0, 1);
            }
        }

        # ３．長音 ヘボン式では長音を表記しない
        elsif ($hr->{char} eq "ー") {
            $hr->{hepburn} = "";
        }

        if (defined $hr->{hepburn}) {
            if ($last_hepburn) {
                my $h_test = $last_hepburn . $hr->{hepburn};
                if (length $h_test > 2) {
                    $h_test = substr $h_test, -2;
                }

                # ３．長音 ヘボン式では長音を表記しない
                if (grep $h_test eq $_, qw( AA II UU EE )) {
                    $hr->{hepburn} = '';
                }

            }

            $output .= $hr->{hepburn};
        } else {
            $output .= $hr->{char};
        }

        $last_hepburn = $hr->{hepburn};
        $last_char    = $hr->{char};
        $i += length $hr->{char};
    }

    return ucfirst(lc($output));
}

while(<STDIN>) {
    chomp;
    my @arr = map { romanize($_) } split(/ /);
    print "@arr\n";
}

