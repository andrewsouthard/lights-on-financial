#!/usr/bin/perl
use strict;
use warnings;

# FinancialModern libraries.
use lib ".";
use FinancialModern::LightsOn;

# Parse the imput arguments
my $database = $ARGV[0];
my $reInitDB = $ARGV[1];

if(! -e $database || $reInitDB) {
    my $lo = FinancialModern::LightsOn->new($database);
    $lo->initializeDatabase() || do {
        print "Failed initializing database!\n";
	exit 1;
    };
}
exit 0;
