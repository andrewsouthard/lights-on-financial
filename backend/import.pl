#!/usr/bin/perl
use strict;
use warnings;

# FinancialModern libraries.
use lib ".";
use FinancialModern::Import;
use FinancialModern::LightsOn;

# Parse the imput arguments
my $filename = $ARGV[0];
my $accountName = $ARGV[1];
my $reinit = $ARGV[2];
my $database = $ARGV[3];

if(! -e $database) {
        print "Database does not exist!\n";
        exit 1;
}
# Setup the import library.
my $import = FinancialModern::Import->new($database);
my $result;

if($filename =~/\.csv/) {
    $result = $import->importCSV($filename,$accountName);
} else {
    $result = $import->importOFX($filename,$accountName);
}
print $import->message()."\n";
if(! $result) {
    print "Failed during import!\n";
    exit 1;
}

# Tag transactions.
my $lo = FinancialModern::LightsOn->new($database);
$lo->applyTaggingRules() || do {
        print "Failed categorizing transactions!\n";
	exit 1;
};
exit 0;
