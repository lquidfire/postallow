#!/usr/bin/perl
# Source: https://github.com/lquidfire/route-summarization
# based on original from http://adrianpopagh.blogspot.com/2008/03/route-summarization-script.html

use strict;
use warnings;
use Net::CIDR::Lite;
use Getopt::Long;

GetOptions(
    'spf'   => \my $spf,
    'quiet' => \my $quiet,
    'help'  => \my $help
);

if ($help) {
    print "usage: $0\n";
    print "\t-h|--help\tprint usage\n";
    print "\t-q|--quiet\tsuppress outputs\n";
    print "\t-s|--spf\tadd support for parsing spf prefixes\n";
    print "\nThis script summarizes your IP classes (if possible).\n";
    print "Input IPv4 or IPv6 with CIDR mask one per line. End with CTRL+D.\n\n";
    print "Optionally, redirect a file to stdin like so:\n";
    print "$0 < cidr.txt \n";
    exit;
}

if (!$quiet) { print "# Enter IP/Mask one per line (1.2.3.0/24). End with CTRL+D.\n"; }

my $cidr4 =Net::CIDR::Lite->new;
my $cidr6 =Net::CIDR::Lite->new;

while (<>) {
    my $line = $_;
    chomp $line;

    $line =~ s/^\s*(.*?)\s*$/$1/;

    if ($spf) {
        $line =~ s/^ip[4,6]://;
    }

    if( $line =~ m/^(\d\d?\d?)\.(\d\d?\d?)\.(\d\d?\d?)\.(\d\d?\d?)\/(\d\d?)$/ &&
                  ( $1 <= 255 && $2 <= 255 && $3 <= 255 && $4 <= 255 && $5 <=32) ) {
        $cidr4->add_any($line);

    } elsif( $line =~ m/^(\d\d?\d?)\.(\d\d?\d?)\.(\d\d?\d?)\.(\d\d?\d?)$/ &&
                  ( $1 <= 255 && $2 <= 255 && $3 <= 255 && $4 <= 255) ) {
        $cidr4->add("$line/32");

    } elsif( $line =~ m/:/ ) {
        eval {$cidr6->add_any($line)};
        if ($@) {
            if (!$quiet) { print "# Ignoring IPv6: $line\n"; }
        }

    } else {
        if (!$quiet) { print "# Ignoring: $line\n"; }
    }
}

my @cidr4_list = $cidr4->list;
my @cidr6_list = $cidr6->list;
if (!$quiet) { print "# Aggregated IP list:\n"; }
foreach my $item4(@cidr4_list){
    $item4 =~ s/\/32//;
    if ($spf) { print "ip4:"; }
    print "$item4\n";
}
foreach my $item6(@cidr6_list){
    if ($spf) { print "ip6:"; }
    print "$item6\n";
}
