use strict;
use warnings;

package FinancialModern;

# GLOBALS
#my $SQL_HOST = ':host=127.0.0.1';
#my $SQL_USER = "root";
#my $SQL_PASS = "Ibifase0";
#my $SQL_DB   = "site";
#my $SQL_DRIVER = 'database=mysql';


### NEW
my $SQL_HOST = '';
my $SQL_USER = "";
my $SQL_PASS = "";
my $SQL_DB   = "lof.sqlite";
my $SQL_DRIVER = 'SQLite';


my %REGEX = (
    'alpha' => qr/[A-Za-z0-9\:\,\'\"\#\-\.\\\/ ]+/,
    'float' => qr/[0-9]+(\.[0-9]+)*/,
    'integer' => qr/[0-9]+/,
);
use lib './lib/perl5/';
use DBI;
use Class::Tiny qw(message);

#####################################################################
#        Name: _verifyInput
#  Parameters: required - a hash ref of required fields with the hash value of 
#                         the field type
#                  args - a hash reference of the provided fields.
#      Return: 1 if all required fields were provided, 0 otherwise.
# Description: An automated way to verify that all the required fields were 
#              provided without extensive and repeditve checks in the subroutine
#####################################################################
sub _verifyInput {
    my $self     = shift;
    my $required = shift;
    my $args     = shift;

    foreach my $field (keys %$required) {
        unless(defined $self->$field) {
            $self->message("Required field $field not provided!");
            return 0;
        }
        unless($self->$field =~ $REGEX{$required->{$field}}) {
            $self->message("Field $field not of type ".$required->{$field}."!");
            return 0;
        }
    }
    return 1;
}

#####################################################################
#        Name: _getDBH
#      Return: a database handle.
#####################################################################
sub _getDBH {
    my $self = shift;
    my $db   = $self->db || $SQL_DB;
    return DBI->connect("DBI:$SQL_DRIVER:$db", '', '',
                        { 'RaiseError' => 1, 'AutoCommit' => 1, 'PrintError' => 0,});
}


sub TO_JSON {
      return { %{ shift() } };
}
1; 

################################################################################
# FinancialModern::Account
################################################################################

package FinancialModern::Account;

use lib '.';
use lib './lib/perl5/';
use parent 'FinancialModern';
use Class::Tiny qw(acctID acctNum acctType balance id importDate importID lastUpdated message name routing);
use Digest::SHA qw(sha1_hex);


#####################################################################
#        Name: new
#      Return: self
# Description: Instantiate a new object.
#####################################################################
sub new {
    my $class = shift;

    # Instantiate.
    my $self  = {};
    bless $self,$class;

    return $self;
}

sub verify {
    my $self = shift;

    unless($self->acctID()) {
        if($self->acctNum() && $self->routing()) {
            $self->_genAcctID();
        } else {
            $self->message("Account number and routing number must be provided!");
            return 0;
        }
    }

    my %required = (
        'acctID'      => 'alpha',
        'balance'     => 'float',
        'importID'    => 'integer',
        'lastUpdated' => 'integer',
        'name'        => 'alpha',
    );

    if(! $self->_verifyInput(\%required)) {
        return 0;
    }

    return 1
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

    $self->acctID(sha1_hex($self->routing().$self->acctNum()));
    $self->routing("");
    $self->acctNum("");
}
1;


################################################################################
# FinancialModern::Tag
################################################################################

package FinancialModern::Tag;
use lib '.';
use lib './lib/perl5/';
use parent 'FinancialModern';
use Class::Tiny qw(id name category);

#####################################################################
#        Name: new
#      Return: self
# Description: Instantiate a new object.
#####################################################################
sub new {
    my $class = shift;

    # Instantiate.
    my $self  = {};
    bless $self,$class;

    return $self;
}

sub verify {
    my $self = shift;
   
    my %required = (
        'name'  => 'alpha',
        'category' => 'alpha',
    );

    if(! $self->_verifyInput(\%required)) {
        return 0;
    }

    return 1;
}

1;
################################################################################
# FinancialModern::Todo
################################################################################

package FinancialModern::Todo;
use lib '.';
use lib './lib/perl5/';
use parent 'FinancialModern';
use Class::Tiny qw(id type need given);

#####################################################################
#        Name: new
#      Return: self
# Description: Instantiate a new object.
#####################################################################
sub new {
    my $class = shift;

    # Instantiate.
    my $self  = {};
    bless $self,$class;

    return $self;
}

sub verify {
    my $self = shift;
   
    my %required = (
        'type'  => 'alpha',
        'need'  => 'alpha',
        'given' => 'alpha',
    );

    if(! $self->_verifyInput(\%required)) {
        return 0;
    }

    return 1;
}

1;
################################################################################
# FinancialModern::Transaction
################################################################################

package FinancialModern::Transaction;
use lib '.';
use lib './lib/perl5/';
use parent 'FinancialModern';
use Class::Tiny qw(acctID acctName amount balance date description id importID tag transID type);

#####################################################################
#        Name: new
#      Return: self
# Description: Instantiate a new object.
#####################################################################
sub new {
    my $class = shift;

    # Instantiate.
    my $self  = {};
    bless $self,$class;

    return $self;
}

sub verify {
    my $self = shift;
   
    my %required = (
        'acctID'      => 'alpha',
        'amount'      => 'float',
        'balance'     => 'float',
        'date'        => 'integer',
        'description' => 'alpha',
        'importID'    => 'integer',
        # DEBIT  is a 0
        # CREDIT is a 1 (since if credit, display minus sign).
        'type'        => 'integer',
    );

    if(! $self->_verifyInput(\%required)) {
        return 0;
    }

    $self->_genTransactionID();

    return 1;
}

sub _genTransactionID {
    my $self = shift;
    
    my $string = $self->date.$self->amount.$self->balance.$self->acctID;
    $self->transID(Digest::SHA::sha1_hex($string));
    return 1;

}
1;
