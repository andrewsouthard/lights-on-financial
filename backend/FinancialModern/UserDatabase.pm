use strict;
use warnings;

package FinancialModern::UserDatabase;

use lib '.';
use parent 'FinancialModern';
use Class::Tiny qw(db);

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
    #return undef unless(defined($user) && $user->isAuthenticated());

    # Save the user db name for later use.
    #my $db = $user->userdb
    my $db = 'lof.sqlite';
    $self->db($db);

    return $self;
}


#####################################################################
#        Name: add
#  Parameters: Account, Transaction, Todo or Tag object to be added.
#      Return: Returns 1 on success, 0 on failure.
# Description: 
#####################################################################
sub add {
    my $self = shift;
    my $item = shift;

    my $type = ref $item;

    # Clear the message if it is set.
    $self->message("");

    #
    # Make sure the item is valid.
    if(! $item->verify()) {
        $self->message($item->message.Dumper($item));
        return 0;
    }

    my $dbh = $self->_getDBH();
    if(! defined $dbh) {
        $self->message("Could not connect to the database!");
        goto NO_AUTH;
    }

    if($type eq 'FinancialModern::Account') {
        my $sth = $dbh->prepare("SELECT * FROM accounts where acctID=? and balance=? and lastUpdated=?");
        eval { $sth->execute($item->acctID,$item->balance(),$item->lastUpdated()) };
        if($@) {
            $self->message("Failed to query accounts! $@");
            $sth->finish();
            $dbh->disconnect();
            return 0;
        }
        if($sth->rows > 0) {
            $self->message("The account entry already exists!");
            $sth->finish();
            $dbh->disconnect();
            return 2;
        }

        $sth = $dbh->prepare("INSERT INTO accounts values(NULL,?,?,?,?,?,?,?)");
        eval { $sth->execute($item->acctID,$item->acctType(),$item->name(),$item->lastUpdated(),$item->balance(),time(),$item->importID()) };
        if($@) {
            $self->message("Failed to add account! $@");
            $dbh->disconnect();
            return 0;    
        }
    } elsif($type eq 'FinancialModern::Todo') {
        my $sth = $dbh->prepare("SELECT * FROM todos where type=? and need=? and given=?");
        eval { $sth->execute($item->type,$item->need(),$item->given()) };
        if($@) {
            $self->message("Failed to query todos! $@");
            $sth->finish();
            $dbh->disconnect();
            return 0;
        }
        if($sth->rows > 0) {
            $self->message("The todo entry already exists!");
            $sth->finish();
            $dbh->disconnect();
            return 2;
        }

        $sth = $dbh->prepare("INSERT INTO todos values(NULL,?,?,?)");

        #id  need given
        eval { $sth->execute($item->type(),$item->need(),$item->given()) };
        if($@) {
            $self->message("Failed to add todo! $@");
            $dbh->disconnect();
            return 0;
        }
        $sth->finish();
    } elsif($type eq 'FinancialModern::Transaction') {
        my $sth = $dbh->prepare("INSERT INTO transactions values(NULL,?,?,?,?,?,?,?,?,?)");

        # Transaction ID prevents duplicate transactions from being added.
        my $transID = Digest::SHA::sha1_hex($item->acctID.$item->balance.$item->amount.$item->date);

        #id  acctId balance  amount  type  date  description  tag  importID  transID
        eval { $sth->execute($item->acctID,$item->balance(),$item->amount(),$item->type(),$item->date(),$item->description(),$item->tag(),$item->importID(),$transID) };
        if($@) {
            if($@ =~ "Duplicate entry .* for key 'transID'") {
                $self->message($@);
                $dbh->disconnect();
                return 2;
            } elsif($@ =~ /UNIQUE constraint failed: transactions\.transID/) {
                # No need to return a failure here. Just skip the duplicate.
                $self->message($@);
            } else {
                $self->message("Failed to add transaction! $@");
                $dbh->disconnect();
                return 0;
            }
        }
        $sth->finish();
    } elsif($type eq 'FinancialModern::Tag') {
        my $sth = $dbh->prepare("SELECT * FROM tags where name=? and category=?");
        eval { $sth->execute($item->name,$item->category()) };
        if($@) {
            $self->message("Failed to query tags! $@");
            $sth->finish();
            $dbh->disconnect();
            return 0;
        }
        if($sth->rows > 0) {
            $self->message("The tag already exists!");
            $sth->finish();
            $dbh->disconnect();
            return 2;
        }

        $sth = $dbh->prepare("INSERT INTO tags values(NULL,?,?)");

        eval { $sth->execute($item->name(),$item->category()) };
        if($@) {
            $self->message("Failed to add tag! $@");
            $dbh->disconnect();
            return 0;
        }
        $sth->finish();
    } else {
        return 0; 
    }

    $dbh->disconnect();
    return 1;
}

#####################################################################
#        Name: _parseSpecifier
#  Parameters: specifier - array reference of specifiers
#      Return: Array reference of objects on success, undef on failure
# Description: Queries the database for entries matching the provided criteria. 
#####################################################################
sub _parseSpecifier {
    my $self      = shift;
    my $specifier = shift;
    my $inclusive = shift || 0;
    my $table     = shift || "";

    my $specString = "";

    return $specString unless(ref $specifier eq 'ARRAY');
    foreach my $spec (@$specifier) {
        my $string   = $table.".".$spec->{'name'};
        my $selector = $spec->{'selector'};

        if($selector eq 'is') {
            if($spec->{'value'} eq '') {
                $string .= ' is NULL';
            } else {
                $string .= '="'.$spec->{'value'}.'"';
            }
        } elsif($selector eq 'between') {
            $string .= ' between '.$spec->{'start'}.' and '.$spec->{'end'};
        } elsif($selector eq 'like') {
            $string .= ' like "%'.$spec->{'value'}.'%"';
        }

        if(length($specString)) {
            if($inclusive) {
                $specString .= " or $string";
            } else {
                $specString .= " and $string";
            }
        } else {
             $specString = " where $string";
        }
    }

    return $specString;

}
###############################################################################
#        Name: get
#  Parameters: item - an object with information describing what to grab.
#      Return: Array reference of objects on success, undef on failure
# Description: Queries the database for entries matching the provided criteria. 
###############################################################################
sub get {
    my $self       = shift;
    my %args       = @_;
    my $item       = $args{'item'};
    my $select     = $args{'select'}     || "";
    my $specifier  = $args{'specifier'}  || "";
    my $inclusive  = $args{'inclusive'}  || 0;
    my $limit      = $args{'limit'}      || 10;
    my $offset     = $args{'offset'}     || 0;

    unless(defined($item)) {
        $self->message("An object must be provided!");
        return undef;
    }
    # Clear the message if it is set.
    $self->message("");

    my $results = [];
    my $sth;
    my $dbh = $self->_getDBH();
    if(! defined $dbh) {
        $self->message("Could not connect to the database!");
        goto NO_AUTH;
    }
    if(ref $item eq 'FinancialModern::Account') {
        my $searchParams = $self->_defineSearchParams('item' => $item,'table' => 'a');
        my $statement = "select acctID,acctType,name,lastUpdated,balance,importID,id,max(importDate) from (select * from accounts ORDER BY importDate DESC) as a";
        $statement .= $searchParams if(defined($searchParams));
        $statement .= " GROUP BY acctID";
        $sth  = $dbh->prepare($statement);
        eval { $sth->execute() };
        if($@) {
            $self->message("Querying the accounts failed! $@");
            goto NO_AUTH;
        }

        if($sth->rows == 0) {
            $sth->finish();
            $dbh->disconnect;
            return $results;
        }

        while (my @row = $sth->fetchrow_array ) {
            my $a = FinancialModern::Account->new();
            $a->acctID($row[0]);
            $a->acctType($row[1]);
            $a->name($row[2]);
            $a->lastUpdated($row[3]);
            $a->balance($row[4]);
            $a->importID($row[5]);
            $a->id($row[6]);
            $a->importDate($row[7]);
            push(@$results,$a);
        }
    } elsif(ref $item eq 'FinancialModern::Tag') {
        my $statement;
        my $searchParams = undef;
        # If the user has defined specific values vai the object, use those, 
        # otherwise use any specifier values provided.
        if(defined $item->id) {
            $searchParams = $self->_defineSearchParams('item' => $item,'table' => 't');
        }

        if($select eq 'count(*)') {
            $statement = "SELECT $select FROM tags as t ";
            $statement .= $searchParams if(defined($searchParams));
            my $count = $dbh->selectrow_array($statement, undef); 
            $dbh->disconnect;
            return $count;
        }

        $statement = "select id,name,category from tags as t";
        $statement .= $searchParams if(defined($searchParams));
        $statement .= " ORDER BY t.category, t.name";
        $sth  = $dbh->prepare($statement);

        eval { $sth->execute() };
        if($@) {
            $self->message("Querying the tags failed! $@");
            goto NO_AUTH;
        }

        if($sth->rows == 0) {
            $sth->finish();
            $dbh->disconnect;
            return $results;
        }

        while (my @row = $sth->fetchrow_array ) {
            my $t = FinancialModern::Tag->new();
            $t->id($row[0]);
            $t->name($row[1]);
            $t->category($row[2]);
            push(@$results,$t);
        }
    } elsif(ref $item eq 'FinancialModern::Todo') {
        my $statement;
        my $searchParams = $self->_defineSearchParams('item' => $item);

        if($select eq 'count(*)') {
            $statement = "SELECT $select FROM todos";
            $statement .= $searchParams if(defined($searchParams));
            my $count = $dbh->selectrow_array($statement, undef); 
            $dbh->disconnect;
            return $count;
        }

        $statement = "select id,type,need,given from todos ";
        $statement .= $searchParams if(defined($searchParams));
        $statement .= " ORDER BY id DESC,need";
        $sth  = $dbh->prepare($statement);

        eval { $sth->execute() };
        if($@) {
            $self->message("Querying the todos failed! $@");
            goto NO_AUTH;
        }


        if($sth->rows == 0) {
            $sth->finish();
            $dbh->disconnect;
            return $results;
        }

        while (my @row = $sth->fetchrow_array ) {
            my $t = FinancialModern::Todo->new();
            $t->id($row[0]);
            $t->type($row[1]);
            $t->need($row[2]);
            my $given = {};
            foreach my $i (split(",",$row[3])) {
               (my $key,my $val) =  split(":",$i);
               $given->{$key} = $val;
            }
            $t->given($given);
            push(@$results,$t);
        }
    } elsif(ref $item eq 'FinancialModern::Transaction') {
        # Remove the acctName value if it is set since it isn't in the transaction table.
        $item->acctName("");

        # Parse through the provided values and use those to select matching 
        # transactions.
        my $searchParams = $self->_parseSpecifier($specifier,$inclusive,'t') || "";

        # Search tag name too if the search is inclusive and the tag is requested.
        $searchParams =~ s/t\.tag/g\.name/ if($searchParams =~ /t\.tag(?! is NULL)/);

        # Setup pagination variables
        if($offset > 0) {
            $offset -= 1;
            $offset *= $limit;
        }

        my $statement;
        if($select eq 'count(*)') {
            $statement = "SELECT $select FROM transactions as t";
            $statement .= " LEFT JOIN tags AS g ON t.tag=g.id";
            $statement .= $searchParams if(defined($searchParams));
        } elsif($select =~ /sum\(.*\)/) {
            $statement = "SELECT $select FROM transactions AS t";
            $statement .= " LEFT JOIN tags AS g ON t.tag=g.id";
            $statement .= $searchParams if(defined($searchParams));
        } else {
            # Define a statement to use to pull out all relevant values to populate
            # transaction objects.
            $statement = "SELECT DISTINCT t.id,t.acctId,t.balance,t.amount,t.type,t.date,t.description,g.name,t.importID,a.name FROM transactions AS t";
            $statement .= " INNER JOIN accounts AS a ON t.acctId=a.acctID";
            $statement .= " LEFT JOIN tags AS g ON t.tag=g.id";
            $statement .= $searchParams if(defined($searchParams));
            $statement .= " ORDER BY t.date DESC LIMIT $limit OFFSET $offset";
        }

        if($select ne "") {
            my $value = $dbh->selectrow_array($statement, undef); 
            $dbh->disconnect;
            return '0.00' if(! defined($value));
            return $value;
        }

        $sth  = $dbh->prepare($statement);
        eval { $sth->execute() };
        if($@) {
            $self->message("Querying the transactions failed! $statement\n $@");
            goto NO_AUTH;
        }

        if($sth->rows == 0) {
            $sth->finish();
            $dbh->disconnect;
            return $results;
        }

        while (my @row = $sth->fetchrow_array ) {
            my $t = FinancialModern::Transaction->new();
            $t->id($row[0]);
            $t->acctID($row[1]);
            $t->balance($row[2]);
            $t->amount($row[3]);
            $t->type($row[4]);
            $t->date($row[5]);
            $t->description($row[6]);
            $t->tag($row[7]);
            $t->importID($row[8]);
            $t->acctName($row[9]);
            push(@$results,$t);
        }
    }

    $sth->finish() if(defined($sth));
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
###############################################################################
#        Name: getDateRange
#  Parameters:
#      Return: Hash ref of columns with range in the form: start,end on success,
#              undef on failure
# Description:
###############################################################################
sub getDateRange {
    my $self       = shift;
    my %args       = @_;
    my $table      = $args{'table'}      || undef;
    my $column     = $args{'column'}     || undef;
    my $ranges     = undef;

    unless(defined($table) && defined($column)) {
        $self->message("Could not connect to the database!");
        return undef;
    }

    # Get the DBH.
    my $dbh = $self->_getDBH();
    if(! defined $dbh) {
        $self->message("Could not connect to the database!");
        return undef;
    }

    # Define a statement to use to pull out all relevant values to populate
    # transaction objects.
    my $statement = "select $column,min(date),max(date) from $table group by $column";

    my $sth  = $dbh->prepare($statement);

    eval { $sth->execute() };
    if($@) {
        $self->message("Querying the $table failed! $@");
        goto NO_AUTH;
    }

    if($sth->rows == 0) {
        $sth->finish();
        $dbh->disconnect;
        return undef;
    }

    $ranges = {};
    while (my @row = $sth->fetchrow_array ) {
        $ranges->{$row[0]} = $row[1].",".$row[2];
    }

NO_AUTH:
    $sth->finish() if(defined($sth));
    $dbh->disconnect;
    return $ranges;
}
#####################################################################
#        Name: update
#  Parameters: items - an array of populated objects to update.
#              delete - 1 to set a value to "" if the value is defined that
#                       way in the object, 0 otherwise.
#      Return: 1 on success, 0 on failure.
# Description: Updates the database entries matching the ids of the objects provided. 
#####################################################################
sub update {
    my $self      = shift;
    my $items     = shift;
    my $delete    = shift || 0;

    unless(defined($items) && ref($items) eq 'ARRAY') {
        $self->message("An array of objects must be provided!");
        return 0;
    }

    # Clear the message.
    $self->message("");

    # Get the database handle.
    my $dbh = $self->_getDBH();
    if(! defined $dbh) {
        $self->message("Could not connect to the database!");
        goto NO_AUTH;
    }

    my $sth;

    foreach my $item (@$items) {

        my $table; 
        # Define the table that should be updated.
        if(ref $item eq 'FinancialModern::Account') {
            $table = 'accounts';        
        } elsif(ref $item eq 'FinancialModern::Tag') {
            $table = 'tags';        
        } elsif(ref $item eq 'FinancialModern::Todo') {
            $table = 'todos';        
        } elsif(ref $item eq 'FinancialModern::Transaction') {
            $table = 'transactions';        
        } else {
            $table = '';
        }

        # Start creating the statement. 
        my $statement = "update $table "; 

        # Gather the parameters to update
        $statement .= $self->_defineUpdateParams($item,$delete);

        $statement .= " where id=".$item->id();
        $sth  = $dbh->prepare($statement);
        eval { $sth->execute() };
        if($@) {
            $self->message("Updating $table failed! $statement $@");
            goto NO_AUTH;
        }

        goto NO_AUTH if($sth->rows() < 1);

        $sth->finish();
    }

    $dbh->disconnect;
    return 1;

NO_AUTH:
    $sth->finish if(defined($sth));
    $dbh->disconnect if(defined($dbh));
    return 0;
}

sub delete {
    my $self = shift;
    my $item = shift;

    unless(defined($item)) {
        $self->message("Objects to delete from the database must be provided.");
        return 0;
    }

    # Clear the message if it is set.
    $self->message("");

    my $dbh = $self->_getDBH();
    if(! defined $dbh) {
        $self->message("Could not connect to the database!");
        goto NO_AUTH;
    }

    my $id;
    my $col;
    my $table;
    if(ref $item eq 'FinancialModern::Account') {
        $col = "acctID";
        $id = $item->acctID();
        if(! defined($id)) {
            $id = $item->importID();
            $col = "importID";
        }
        $table = 'accounts';
    } elsif(ref $item eq 'FinancialModern::Transaction') {
        $col = "id";
        $id = $item->id();
        if(! defined($id)) {
            $id = $item->importID();
            $col = "importID";
        }
        $table = 'transactions';
    } elsif(ref $item eq 'FinancialModern::Tag') {
        $id = $item->id();
        $col = "id";
        $table = 'tags';
    } elsif(ref $item eq 'FinancialModern::Todo') {
        $id = $item->id();
        $col = "id";
        $table = 'todos';
    }

    # Verify an ID was provided.
    if(! defined($id)) {
        $self->message("ID to delete must be defined!");
        goto NO_AUTH;
    }

    eval {$dbh->do("DELETE FROM $table where $col=\"$id\"") };
    if($@) {
        $self->message("Removing $col of $id from $table failed! $@");
        goto NO_AUTH;
    }

    # If the type is Tag, set all transactions associated with that tag to have
    # a tag of null.
    if(ref $item eq 'FinancialModern::Tag') {
        eval { $dbh->do("UPDATE transactions SET tag=NULL where tag=\"$id\""); };
        if($@) {
            $self->message("Failed to remove the tag from associated transactions!");
            goto NO_AUTH;
        }
    }


    $dbh->disconnect;

    return 1;

NO_AUTH:

    $dbh->disconnect if(defined($dbh));
    return 0;

}
sub _defineSearchParams {
    my $self    = shift;
    my %args    = @_;
    my $item    = $args{'item'} || undef;
    my $table   = $args{'table'} || undef;
    my $or      = $args{'or'}    || 0;
    my $useLike = $args{'useLike'} || 0;

    my @items = keys(%$item);

    if(defined($table)) {
        $table .= ".";
    } else {
        $table = "";
    }
    my $searchParams = undef;
    return $searchParams if(scalar keys(%$item) == 0);

    if(scalar @items == 1) {
        my $key = $items[0];
        my $val = $item->$key; 
        $key = $table.$key;

        return "" if(! defined($val) or $val eq '');

        return " where $key like \"%$val\"" if($useLike);
        return " where $key=\"$val\"";
    } 
    
    $searchParams= "";
    my @paramsArr = ();
    for(my $i = 0; $i < scalar @items; $i++) {

        # Only defined values will have a key defined.
        my $key = $items[$i];
        my $val = $item->$key;
        if(ref $val  eq 'HASH') {
            my @newVal;
            foreach my $k (reverse keys %$val) {
                push(@newVal,"$k:".$val->{$k});
            }
            $val = join(",",@newVal);
        }

        # Skip all entries that have an empty value.
        next if(! defined($val) or $val eq '');

        # Append the table name.
        $key = $table.$key;

        # Add to the searchParams
        if($useLike) {
            push(@paramsArr,"$key like \"%$val%\"");
        } else {
            push(@paramsArr,"$key=\"$val\"");
        }
    }

    # Insert an "and" or "or" between search parameters.
    if($or) {
        $searchParams .= join(" or ",@paramsArr);
    } else {
        $searchParams .= join(" and ",@paramsArr);;
    }


    return "" if($searchParams eq "" );
    return " where $searchParams ";
}

sub _defineUpdateParams {
    my $self         = shift;
    my $item         = shift;
    my $deleteBlank  = shift || 0;
    my @items        = keys(%$item);
    my @paramsArr    = ();
    my $updateParams = undef;

    # Return undef if there are no parameters to update.
    return $updateParams if(scalar keys(%$item) == 0);


    # If there is only one parameter, return the string.
    if(scalar @items == 1) {
        my $key = $items[0];
        my $val = $item->$key;
        return "set $key=\"$val\"";
    } 
    
    $updateParams = "set ";
    for(my $i = 0; $i < scalar @items; $i++) {
        # Only defined values will have a key defined.
        my $key = $items[$i];
        my $val = $item->$key || "";

        # The id should never be updated.
        next if($key eq 'id');

        # acctName is not in the database and used just for import so it can't be updated.
        next if(ref $item eq 'FinancialModern::Transaction' && $key eq 'acctName');

        # Only set a value if it is defined. 
        next if($val eq '' && ! $deleteBlank);

        # Add to the updateParams
        if(ref $item eq 'FinancialModern::Transaction' && $key eq 'tag' && $val !~ /^[0-9]+$/) { 
            $val = "(select id from tags where name=\"$val\" limit 1)";
            push(@paramsArr,"$key=$val");
        } else {
            push(@paramsArr,"$key=\"$val\"");
        }

    }
    $updateParams .= join(",",@paramsArr);
    return $updateParams;
}

1;
