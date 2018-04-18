use strict;
use warnings;

package FinancialModern::LightsOn;

use lib '.';
use lib './lib/perl5';
use parent 'FinancialModern';
use Class::Tiny qw(db message);
use DateTime;

#####################################################################
#        Name: new
#  Parameters: none
#      Return: self
# Description: Instantiate a new object.
#####################################################################
sub new {
    my $class = shift;
    my $udb = shift;

    # Instantiate.
    my $self  = {};
    bless $self,$class;

    if(defined $udb) {
        $self->db($udb);
    }

    return $self;
}

#####################################################################
#        Name: initializeDatabase
#  Parameters: none
#      Return: 1 on success, 0 on failure
# Description: Create the database tables and populate default rules.
#####################################################################
sub initializeDatabase {
    my $self = shift;

    # Define the tables to add.
    my @tables;
    push(@tables,"CREATE TABLE accounts (id INTEGER PRIMARY KEY, acctId VARCHAR(50) NOT NULL, acctType VARCHAR(100), name VARCHAR(255), lastUpdated INTEGER, balance DECIMAL(13,2), importDate INTEGER NOT NULL,importID INTEGER NOT NULL)");
    #push(@tables,"CREATE TABLE tags (id INTEGER PRIMARY KEY, name VARCHAR(255) NOT NULL, category VARCHAR(255) NOT NULL)");
    push(@tables,"CREATE TABLE rules (id INTEGER PRIMARY KEY, category VARCHAR(255) NOT NULL, tomatch VARCHAR(255) NOT NULL)");
    push(@tables,"CREATE TABLE todos (id INTEGER PRIMARY KEY, type VARCHAR(50) NOT NULL, need VARCHAR(50) NOT NULL, given VARCHAR(255))");
    push(@tables,"CREATE TABLE categories (id INTEGER PRIMARY KEY, name VARCHAR(80) NOT NULL, income BOOL NOT NULL)");
    #id|acctID|balance|amount|type|date|description|category|importID
    push(@tables,"CREATE TABLE transactions (id INTEGER PRIMARY KEY, acctId VARCHAR(50) NOT NULL, balance DECIMAL(13,2), amount DECIMAL(13,2), type TINYINT(1), date INTEGER, description VARCHAR(255), category VARCHAR(255), importID INTEGER NOT NULL, transID VARCHAR(255) UNIQUE)");
 
    # DEFAULT CATEGORIES
    my @defaultCategories = (
    'Clothing|0',
    'Donations|0',
    'Education|0',
    'Food|0',
    'Gifts|0',
    'Healthcare|0',
    'Housing/Household|0',
    'Media & Entertainment|0',
    'Miscellaneous|0',
    'Subscriptions/Memberships|0',
    'Taxes|0',
    'Transportation|0',
    'Utilities|0',
    'Vacation|0',
    # Income categories
    'Salary|1',
    'Interest|1',
    'Investments|1',
    );
    
    # DEFAULT RULES
    my @defaultRules = (
    "Food|starbucks",
    "Housing/Household|target",
    "Housing/Household|wal-mart",
    "Donations|cru",
    "Food|caribou",
    "Food|mcdonald",
    "Food|taco bell",
    "Food|cafe carolina",
    "Food|food lion",
    "Food|trader joe",
    "Food|Harris Teeter",
    "Food|KROGER",
    "Food|bojangles",
    "Transportation|Circle K",
    "Transportation|EXXONMOBIL",
    "Food|WHOLEFDS",
    "Transportation|HAN-DEE HUGO",
    "Transportation|SHEETZ",
    "Transportation|SHELL",
    "Transportation|gastown",
    "Transportation|citgo",
    "Food|Guasaca",
    "Food|Salsa Fresh",
    "Transportation|Advance Auto Parts",
    "Food|Bojangles",
    "Food|Panera Bread",
    "Food|Yellow Dog Bread",
    "Healthcare|FITNESS CONNECTION",
    "Food|cook out",
    "Food|chipotle",
    "Food|Cafe Carolina",
    "Food|Chick-fil-a",
    "Food|PAPA JOHN",
    );

    my $dbh = $self->_getDBH();

    foreach my $table (@tables) {
        eval { $dbh->do($table) };
        if($@) {
            print "Creating user database table failed! $@ ";
            goto FAIL;
        }
    }

    # Add default categories
    foreach my $cat (@defaultCategories) {
        (my $name ,my $income) = split('\|',$cat);
        my $statement = "INSERT INTO categories values(NULL,'$name','$income')";
        eval { $dbh->do($statement) };
        if($@) {
            print "Inserting category failed! $@\n";
            print "$statement\n";
            goto FAIL;
        }
    }
    # Add default rules
    foreach my $rule (@defaultRules) {
        (my $category,my $tomatch) = split('\|',$rule);
        my $statement = "INSERT INTO rules values(NULL,'$category','$tomatch')";
        eval { $dbh->do($statement) };
        if($@) {
            print "Inserting tagging rule failed! $@\n";
            print "$statement\n";
            goto FAIL;
        }
    }

    eval { $dbh->disconnect; };
    if($@) {
        print "Failed to disconnect from the user database! $@";
        return 0;
    }

    return 1;
FAIL:
    eval { $dbh->disconnect; };
    return 0;

}
#####################################################################
#        Name: applyTaggingRules
#  Parameters: none
#      Return: 1 on success, 0 on failure. 
# Description: Apply the predefined rules to transactions in 
#              the database.
#####################################################################
sub applyTaggingRules {
    my $self = shift;

    my $dbh = $self->_getDBH();
    
    my $sth  = $dbh->prepare('select category,tomatch from rules');
    eval { $sth->execute() };
    if($@) {
        print "Querying the accounts failed! $@";
        goto FAIL;
    }
    
    while(my @row = $sth->fetchrow_array) {
        my $statement = "SELECT * FROM transactions WHERE LOWER(description) LIKE LOWER(\"%".$row[1]."%\") AND category IS NOT NULL";
        my $sh  = $dbh->prepare($statement);
        eval { $sh->execute() };
        if($@) {
            print "Error querying transactions! $@\n";
            $sh->finish();
            goto FAIL;
        }
        if($sh->rows > 0) {
            print "Collision tagging transactions with category ".$row[0]." and tomatch ".$row[1]."!\n";
        }
        $statement = "UPDATE transactions SET category='".$row[0]."' where LOWER(description) like LOWER(\"%".$row[1]."%\") AND category IS NULL";
        $sh  = $dbh->prepare($statement);
        eval { $sh->execute() };
        if($@) {
            print "Error categorizing transactions! $@\n";
            $sh->finish();
            goto FAIL;
        }
        $sh->finish();
    }
    $sth->finish();
    
    $dbh->disconnect();
    return 1;

FAIL:
    $sth->finish();
    $dbh->finish();
    return 0;
}
1;
