#!/usr/bin/perl
use strict;
use warnings; 


use lib "./lib/perl5";
use Data::Dumper;
use DBI;
use Email::Stuffer;
use FileHandle;
use JSON;

# FinancialModern libraries.
use lib ".";
use FinancialModern::Import;
use FinancialModern::LightsOn;

# GLOBALS
my $SQL_HOST = ':host=127.0.0.1';
my $SQL_USER = "lof";
my $SQL_PASS = 'LOF4@ll!!';
my $SQL_DB   = "database=website";
my $SQL_DRIVER = 'mysql';
my $UPLOAD_DIR = '/var/www/html/uploads/';
my $database  = 'lof.sqlite';
my $spreadsheet = 'budget-sheet.xlsx';
my $ADMIN_EMAIL = 'andrew@lightsonfinancial.com';
my $FROM_EMAIL = 'Lights On Financial <no-reply@lightsonfinancial.com>';
my @ERRORS;
my $PROCESSED = 0;
my $messageBody = ",\n
Thank you for choosing Lights On Financial! You will find your spreadsheet attached. If you have any questions, check out our help page at the link below or drop us a line at help\@lightsonfinancial.com.

http://www.lightsonfinancial.com/using-your-spreadsheet.html

Cheers,
Your Friends at Lights On Financial";
sub sendAdminEmail {
    my $user = shift;
    my $subject = "LOF: Successfully processed spreadsheet request.";
    my $body = "Request successfully processed for ".$user->{'email'};
    if(scalar(@ERRORS) > 0) {
            $subject = "LOF: ERROR processing spreadsheet request";
           $body = Dumper($user);
           $body .= join("\n",@ERRORS);
    }
    Email::Stuffer->to($ADMIN_EMAIL)
                  ->from($FROM_EMAIL)
                  ->text_body($body)
                  ->subject($subject)
                  ->send;
}

sub sendUserEmail {
    my $user = shift;
    my $body = $user->{'name'}.$messageBody;
    my $subject  = 'Your Budget Spreadsheet';
    Email::Stuffer->to($user->{'email'})
                  ->from($FROM_EMAIL)
                  ->text_body($body)
                  ->subject($subject)
                  ->attach_file($spreadsheet)
                  ->send;
}
sub makeUser {
    my $entry = shift;
    my %files;
    foreach my $fileObj (@{decode_json $entry->[2]}) {
        my $file = $UPLOAD_DIR.$entry->[1].$fileObj->{'file'};
        next unless(-e $file);
            $files{$fileObj->{'name'}} = $file;
        }
      
    return { 
        'name' => $entry->[0],
        'email' => $entry->[1],
        'files'=> \%files, 
    };
}

my $dbh = _getDBH();
my $statement = "SELECT name,email,filenames,id FROM entries WHERE processed=$PROCESSED";
my $entries = $dbh->selectall_arrayref($statement);
foreach my $entry (@$entries) {
    unlink $database  if(-e $database);
    unlink $spreadsheet if(-e $spreadsheet );
    # Generate an object from the database info.
    my $user = makeUser($entry);

    foreach my $acctname (keys %{$user->{'files'}}) {
        my $filePath = $user->{'files'}->{$acctname};
        my $importStatus = import($filePath,$acctname);
        if(! $importStatus) {
            push(@ERRORS,"Error importing $filePath!");
            # Update the database so we don't keep trying to process the spreadsheet.
            eval { $dbh->do("UPDATE entries SET processed=2 WHERE id=".$entry->[3]); } ;
            last;
        } 
    }

    if(scalar @ERRORS == 0 ) {
        my $spreadsheetCall = system("perl outToSpreadsheet.pl" );
            if($spreadsheetCall > 0) {
                push(@ERRORS,"Error generating spreadsheet for ".$user->{'email'});
            } else {
                sendUserEmail($user);
                eval { $dbh->do("UPDATE entries SET processed=1 WHERE id=".$entry->[3]); } ;
                if($@) {
                    push(@ERRORS,"Error updating database for ".$user->{'email'}." $@");
                } else {
                    # Remove all of the files since we've successfully processed them.
                    foreach my $file (values %{$user->{'files'}}) {
                        unlink $file;
                    }
                }
            }
    }
    sendAdminEmail($user);
    @ERRORS = ();
}

# Clean up user files after the last entry is processed.
unlink $database  if(-e $database);
unlink $spreadsheet if(-e $spreadsheet );

#
#####################################################################
#        Name: import
#      Return: 1 on success, 0 on failure
#####################################################################
sub import {
    my $filename = shift;
    my $acctName = shift;

    my $lo = FinancialModern::LightsOn->new();
    if(-e $database) {
        unlink $database;
    }
    $lo->initializeDatabase() || do {
        print "Failed initializing database!\n";
        return 0;
    };

    my $import = FinancialModern::Import->new();
    my $result;
    if($filename =~ /\.csv/) {
        $result = $import->importCSV($filename,$acctName);
    } else {
        $result = $import->importOFX($filename,$acctName);
    }
    if(! $result) {
        push(@ERRORS,"Failed during import of $filename!");
        push(@ERRORS,$import->message());
        return 0;
    }
    $lo->applyTaggingRules() || do {
        push(@ERRORS,"Failed categorizing transactions!");
        return 0;
    };
    return 1;
}



#####################################################################
#        Name: _getDBH
#      Return: a database handle.
#####################################################################
sub _getDBH {
    my $db   = $SQL_DB;
    return DBI->connect("DBI:$SQL_DRIVER:$db$SQL_HOST", $SQL_USER, $SQL_PASS,
        { 'RaiseError' => 1, 'AutoCommit' => 1, 'PrintError' => 0,});
}
