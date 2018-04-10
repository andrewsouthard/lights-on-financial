#!/usr/bin/perl
use strict;
use warnings;

# FinancialModern libraries.
use lib ".";
use FinancialModern::LightsOn;

# Parse the imput arguments
my $reInitDB = $ARGV[1];

my $lo = FinancialModern::LightsOn->new();
if(! -e 'lof.sqlite' || $reInitDB) {
    $lo->initializeDatabase() || do {
        print "Failed initializing database!\n";
	exit 1;
    };
}
exit 0;
