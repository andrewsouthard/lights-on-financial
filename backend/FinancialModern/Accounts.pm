use strict;
use warnings;

package FinancialModern::Accounts;

use lib '.';
use parent 'FinancialModern';
use Class::Tiny qw(balance db id importID lastUpdated message name);

use DBI;
use Data::Dumper;
use Digest::SHA qw(sha1_hex);

#####################################################################
#        Name: new
#  Parameters: user - FinancialModern::Users object.
#      Return: self
# Description: Instantiate a new object.
#####################################################################
sub new {
    my $class = shift;
    my $user  = shift;

    # Instantiate.
    my $self  = {};
    bless $self,$class;

    # Verify a FinancialModern::Users object was provided. This is necessary in 
    # order to get the user's database that we should be querying.
    return undef unless(defined($user) && $user->isAuthenticated());

    # Save the user db name for later use.
    $self->db($user->db);

    return $self;
}


#####################################################################
#        Name: add
#  Parameters: acctNum 
#              balance  
#              importID  
#              lastUpdated
#              name       
#              routing - routing number   
#      Return: Returns acctID on success, undef on failure.
# Description: 
#####################################################################
sub add {
    my $self = shift;
    my %args = @_;

    my %required = (
        'acctNum'     => 'integer',
        'balance'     => 'float',
        'importID'    => 'integer',
        'lastUpdated' => 'integer',
        'name'        => 'alpha',
        'routing'     => 'integer',
    );

    if(! $self->_verifyInput(\%required,\%args)) {
        return undef;
    }

    my $dbh = $self->_getDBH();
    # Generate an account ID that can be used to identify an account without 
    # storing the routing and account numbers.
    my $acctID = $self->_genAcctID($args{'routing'},$args{'acctNum'});

    my $sth = $dbh->prepare("INSERT INTO accounts values(NULL,\"$acctID\",?,?,?,?)");
    $sth->execute($args{'name'},$args{'lastUpdated'},$args{'balance'},$args{'importID'}) || do {
        $self->message("Failed to add account!");
        $dbh->disconnect();
        return undef;    
    };

    $dbh->disconnect();
    return $acctID;

}

#####################################################################
#        Name: get
#  Parameters: acctID - Account ID to retrieve. Calling with all will return an
#                       array of Accounts objects.
#      Return: Array of acct objects on success, undef on failure
# Description: Queries the database for all entries of acctID. There can be many
#              since each import of a account will be included in the database.
#####################################################################
sub get {
    my $self   = shift;
    my $user   = shift;
    my $acctID = shift;

    unless(defined($user) && defined($acctID)) {
        $self->message("An account ID and user object must be provided.");
        return undef;
    }

    my $dbh = $self->_getDBH();
    if(! defined $dbh) {
        $self->message("Could not connect to the database!");
        goto NO_AUTH;
    }

    my $statement = 'select acctId,name,lastUpdated,balance,importID from accounts where acctID=? ORDER BY lastUpdated LIMIT 1';
    if($acctID eq 'all') {
        $statement = "select acctId,name,lastUpdated,balance,importID from (select * from accounts ORDER BY lastUpdated DESC) as sub GROUP BY acctId";
    }
    my $sth  = $dbh->prepare($statement);

    if($acctID eq 'all') {
        $sth->execute();
    } else {
        $sth->execute($acctID);
    }

    my $rows = $sth->rows;
    if($sth->rows == 0) {
        $self->message("Querying the accounts failed!");
        goto NO_AUTH;
    }

    my $results = [];
    while (my @row = $sth->fetchrow_array ) {
        my $a = FinancialModern::Accounts->new($user);
        $a->id($row[0]);
        $a->name($row[1]);
        $a->lastUpdated($row[2]);
        $a->balance($row[3]);
        $a->importID($row[4]);
        push(@$results,$a);
    }
    

    $sth->finish();
    $dbh->disconnect;

    return $results;

NO_AUTH:

    if(defined($sth)) {
        $sth->finish;
    }
    if(defined($dbh)) {
        $dbh->disconnect;
    }
    return undef;

}

sub delete {
    my $self   = shift;
    my $acctID = shift;

    unless(defined($acctID)) {
        $self->message("An account ID must be provided.");
        return 0;
    }

    my $dbh = $self->_getDBH();
    if(! defined $dbh) {
        $self->message("Could not connect to the database!");
        goto NO_AUTH;
    }

    $dbh->do("DELETE FROM accounts where acctId=\"$acctID\"") || do {
        $self->message("Removing the account failed!");
        goto NO_AUTH;
    };

    $dbh->disconnect;

    return 1;

NO_AUTH:

    if(defined($dbh)) {
        $dbh->disconnect;
    }

    return 0;

}

#####################################################################
#        Name: _genAcctID
#  Parameters: routing - the account's routing number,
#              acctNum - the accounts number,
#      Return: a SHA1 hash.
# Description: This subroutine allows to dependably identify an account without 
#              storing the routing number or account number.
#####################################################################
sub _genAcctID {
    my $self = shift;
    my $routing = shift;
    my $acctNum = shift;

    return sha1_hex($routing.$acctNum);
}
1;
