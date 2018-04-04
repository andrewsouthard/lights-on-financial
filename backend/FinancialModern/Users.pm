use strict;
use warnings;

package FinancialModern::Users;

use lib '.';
use parent 'FinancialModern';
# db is the database used to store lists of users. userdb is the user's 
# transaction and account data.
use Class::Tiny qw(db email firstName id ip isAuthenticated message role token userdb);

use DBI;
use Digest;
use Crypt::Random;
use Time::HiRes qw(gettimeofday);

# GLOBALS
my $COST = 4;

#####################################################################
#        Name: new
#  Parameters: token - instantiate via a token (optional) 
#      Return: self
# Description: Instantiate a new object.
#####################################################################
sub new {
    my $class  = shift;
    my %args   = @_;
    my $token  = $args{'token'}  || undef;
    my $ipaddr = $args{'ipaddr'} || undef;
    my $testDB = $args{'testDB'} || undef;

    # Instantiate.
    my $self  = {};
    bless $self,$class;

    $self->db($testDB) if(defined($testDB));

    if(defined($token) && $self->validateToken($token,$ipaddr)) {
        $self->_populateFields();
    } else {
        $self->isAuthenticated(0);
    }

    return $self;
}

#####################################################################
#        Name: authenticate
#  Parameters: username - email address
#              password - user's password
#      Return: { rc: 1, message: "token" } on success, 
#              { rc: 0, message: "reason for error"} on failure
# Description:
#####################################################################
sub authenticate {
    my $self = shift;
    my %args = @_;

    # Clear out any messages.
    $self->message('');

    my $username = $args{'username'} || undef;
    my $password = $args{'password'} || undef;
    my $ipaddr   = $args{'ipaddr'}   || undef;

    unless(defined($username) && defined($password) && defined($ipaddr)) {
        $self->message("A username, password and IP address must be provided.");
        goto NO_AUTH;
    }

    # Populate the email and IP address fields.
    $self->email($username);
    $self->ip($ipaddr);

    # Add backslashes to all nonalpha characters.

    # Get a database handle.
    my $dbh = $self->_getDBH();
    if(! defined $dbh) {
        $self->message("Could not connect to the database!");
        goto NO_AUTH;
    }

    # Log the login attempt.
    my $salt; my $user_pass;
    my $sth = $dbh->prepare("SELECT salt, password from users where email=?");
    eval { $sth->execute($username); };
    if($@) {
        $self->message("Failed to get user information! $@");
        goto NO_AUTH;
    }
    my $rows = $sth->rows;
    if($rows == 0) {
        $self->message("User $username not found.");
        goto NO_AUTH;
    }

    $sth->bind_columns(\$salt, \$user_pass);
    $sth->fetchrow_arrayref;
    $sth->finish;
    eval { $dbh->disconnect; };
    if($@) {
        $self->message("Failed to disconnect from the user database. $@");
        goto NO_AUTH;
    }

    my $bcrypt = Digest->new('Bcrypt');
    $bcrypt->cost($COST);
    $bcrypt->salt($salt);
    $bcrypt->add($password);

    # Get the digest and convert it to UTF since that's what pulling it from the database does.
    my $digest = $bcrypt->digest();

    # Remove any backslashes since they are interpreted as escape characters.
    $digest =~ s/\\//g;
    $user_pass =~ s/\\//g;

    if($digest eq $user_pass) {
        $self->isAuthenticated(1);
        $self->_generateToken() || do {
            $self->message('Failed to generate a token!');
            goto NO_AUTH;    
        };
        $self->_populateFields();
        $self->_logLogin($username,$ipaddr,1);
        return 1;
    } else {
        $self->message("Password is incorrect.");
    }

    NO_AUTH:
    if(defined $sth) {
        $sth->finish;
    }
    
    $self->_logLogin($username,$ipaddr,0);
    eval { $dbh->disconnect; } if(defined $dbh);
    $self->isAuthenticated(0);
    return 0;
}

#####################################################################
#        Name: validateToken
#  Parameters: token - 
#              ipaddr - IP address associated with the token.
#      Return: 1 on success, 0 on failure.
# Description:
#####################################################################
sub validateToken {
    my $self   = shift;
    my $token  = shift;
    my $ipaddr = shift;
    my $tokenTimeout = 3600;
    my $email;
    my $startTime;

    # Make sure a token and an IP address were provided.
    return 0 unless(defined($token) && defined($ipaddr));

    my $dbh = $self->_getDBH();
    if(! defined $dbh) {
        $self->message("Could not connect to the database!");
        goto NO_AUTH;
    }

    my $sth = $dbh->prepare("SELECT email,timestamp FROM tokens where token=? and ip=?");
    eval { $sth->execute($token,$ipaddr); };
    if($@) {
        $self->message("Failed to get tokens from the user database. $@");
        goto NO_AUTH;
    }


    if($sth->rows == 0) {
        $self->message("Invalid token.");
        goto NO_AUTH;
    }

    $sth->bind_columns(\$email, \$startTime);
    $sth->fetchrow_arrayref;
    $sth->finish;

    my $timeoutTime = $startTime + $tokenTimeout;
    my $currTime = time();
    if( time() > $startTime + $tokenTimeout) {
        $self->isAuthenticated(0);
        # Remove the user's token.
        eval { $dbh->do("DELETE FROM tokens where token=\"$token\"") };
        if($@) {
            $self->message("Failed to remove the old token! $@");
        }
        goto NO_AUTH;
        return 0;
    }

    eval { $dbh->disconnect; };
    if($@) {
        $self->message("Failed to disconnect from the database! $@");
        return 0;
    }

    $self->token($token);
    $self->ip($ipaddr);
    $self->isAuthenticated(1);
    $self->email($email);
    return 1;

NO_AUTH:
    
    $sth->finish if(defined $sth);
    eval { $dbh->disconnect; } if(defined $dbh);

    return 0;
}

sub updateToken {
    my $self   = shift;
    my $token  = $self->token;
    my $ipaddr = $self->ip;

    my $dbh = $self->_getDBH();
    if(! defined $dbh) {
        $self->message("Could not connect to the database!");
        goto NO_AUTH;
    }
    my $time = time();
    eval { $dbh->do("UPDATE tokens SET timestamp=\"$time\" where token=\"$token\" and ip=\"$ipaddr\"") };
    if($@) {
        $self->message("Failed to update the user token. $@");
        goto NO_AUTH;
    }
    eval { $dbh->disconnect() };

    return 1;

NO_AUTH:
    eval { $dbh->disconnect; } if(defined $dbh);
    return 0;
}
sub logout {
    my $self   = shift;
    my $token  = $self->token;
    my $ipaddr = $self->ip;

    # Make sure a token and an IP address were provided.
    return 0 unless(defined($token) && defined($ipaddr));

    my $dbh = $self->_getDBH();
    if(! defined $dbh) {
        $self->message("Could not connect to the database!");
        goto NO_AUTH;
    }

    my $sth = $dbh->prepare("DELETE FROM tokens where token=? and ip=?");
    eval { $sth->execute($token,$ipaddr); };
    if($@) {
        $self->message("Failed to delete the user token. $@");
        goto NO_AUTH;
    }


    if($sth->rows == 0) {
        $self->message("Login failed");
        goto NO_AUTH;
    }

    $sth->finish;
    eval { $dbh->disconnect; };
    if($@) {
        $self->message("Failed to disconnect from the database! $@");
        return 0;
    }
    $self->isAuthenticated(0);
    $self->message("Login successful");
    return 1;

NO_AUTH:
    
    $sth->finish if(defined $sth);
    eval { $dbh->disconnect; } if(defined $dbh);

    return 0;


}

sub _generateToken {
    my $self = shift;

    return 0 if(! $self->isAuthenticated);

    my $dbh = $self->_getDBH();
    if(! defined $dbh) {
        $self->message("Could not connect to the database!");
        goto AUTH_FAIL;
    }

    (my $token,undef,undef) = gettimeofday;
    while(length($token) > 20) {
        $token .= int(rand(1));
    }

    my $sth  = $dbh->prepare("INSERT INTO tokens values(NULL,?,?,?,?)");
    eval { $sth->execute($token,$self->email,time(),$self->ip); };
    if($@) {
        $self->message("Failed to insert token. $@");
        goto AUTH_FAIL;
    }

    if($sth->rows == 0) {
        $self->message("Failed to generate token.");
        goto AUTH_FAIL;
    }

    $sth->finish;
    eval { $dbh->disconnect; };
    if($@) {
        $self->message("Failed to disconnect from the user database. $@");
        goto AUTH_FAIL;
    }
    $self->token($token);

    return 1;

AUTH_FAIL:
    
    $sth->finish if(defined $sth);
    eval { $dbh->disconnect; } if(defined $dbh);

    return 0;


}

sub _populateFields {
    my $self = shift;

    return 0 if(! $self->isAuthenticated);

    my $dbh = $self->_getDBH();
    if(! defined $dbh) {
        $self->message("Could not connect to the database!");
        goto DB_FAIL;
    }

    my $sth; my $firstName; my $userdb; my $role; my $email; my $id;

    if(defined($self->email())) {
        $sth = $dbh->prepare("SELECT firstName,db,role,email,id from users where email=?");
        eval {$sth->execute($self->email); };
    } else {
        $sth = $dbh->prepare("SELECT firstName,db,role,email,id from users where id=?");
        eval {$sth->execute($self->id); };
    }
    if($@) {
        $self->message($@);
        goto DB_FAIL;
    }

    if($sth->rows == 0) {
        $self->message("User not found.");
        $sth->finish;
        eval { $dbh->disconnect; };
        return 0
    }
    $sth->bind_columns(\$firstName,\$userdb,\$role,\$email,\$id);
    $sth->fetchrow_arrayref;
    $sth->finish;
    eval { $dbh->disconnect; };
    if($@) {
        $self->message("Failed to disconnect from the database! $@");
        return 0;
    }

    unless(defined($firstName)) {
        $self->message("Failed to retrieve user information.");
        return 0;
    }

    $self->firstName($firstName);
    $self->userdb($userdb);
    $self->role($role);
    $self->email($email);
    $self->id($id);
    return 1;

DB_FAIL:
    $sth->finish if(defined($sth));
    eval { $dbh->disconnect } if(defined($dbh));
    return 0;
}

sub changePassword {
    my $self = shift;
    my %args = @_;
    my $oldPass = $args{'oldPassword'} || undef;
    my $newPass = $args{'newPassword'} || undef;
    my $rows_affected;

    unless(defined($oldPass) && defined($newPass)) {
        $self->message("An old and new password must be provided!");
        return 0;
    }

    if($oldPass eq $newPass) {
        $self->message("The old and new passwords must be different!");
        return 0;
    }

    my $dbh = $self->_getDBH();
    if(! defined $dbh) {
        $self->message("Could not open the database!");
        return 0;

    }

    my $salt; my $user_pass;
    my $sth = $dbh->prepare("SELECT salt,password from users where email=?");
    eval { $sth->execute($self->email) };
    if($@) {
        $self->message("Error when querying users for ".$self->email."! $@");
        goto NO_AUTH;
    }

    my $rows = $sth->rows;
    if($rows == 0) {
        $self->message("User ".$self->email." not found.");
        goto NO_AUTH;
    }
    $sth->bind_columns(\$salt, \$user_pass);
    $sth->fetchrow_arrayref;
    $sth->finish;

    my $bcrypt = Digest->new('Bcrypt');
    $bcrypt->cost($COST);

    $bcrypt->salt($salt);
    $bcrypt->add($oldPass);

    # Get the digest and convert it to UTF since that's what pulling it from the database does.
    my $digest = $bcrypt->digest();

    if($digest ne $user_pass) {
        $self->message('The old password is not correct.');
        goto NO_AUTH;
    }

    $bcrypt->reset;
    $bcrypt->cost($COST);
    $bcrypt->salt($salt);
    $bcrypt->add($newPass);
    my $newPassEnc = $bcrypt->digest();
    eval { $rows_affected = $dbh->do("UPDATE users SET password=\"$newPassEnc\" where email='".$self->email."'") };
    if($@) {
        $self->message("Failed to set the new password! $@");
        return 0;
    }

    eval { $dbh->disconnect; };
    if($@) {
        $self->message("Failed to disconnect from the database! $@");
        return 0;
    }

    if($rows_affected != 1) {
        $self->message('Database error when changing the password.');
        goto NO_AUTH;
    }

    $self->message('Successfully changed the password');
    return 1;

    NO_AUTH:
    if(defined $sth) {
        $sth->finish;
    }
    if(defined $dbh) {
        eval { $dbh->disconnect; };
    }
    return 0;
}

#####################################################################
#        Name: add
#  Parameters:     email - email address
#               password - user's password
#              firstName - user's first name
#               lastName - user's last name
#      Return: 1 on success, 0 on failure
# Description: Add a new user to the database.
#####################################################################
sub add {
    my $self      = shift;
    my %args      = @_;
    my $email     = $args{'email'}     || undef;
    my $password  = $args{'password'}  || undef;
    my $firstName = $args{'firstName'} || undef;
    my $lastName  = $args{'lastName'}  || undef;
    my $testuser  = $args{'testuser'}  || 0;

    unless(defined($email) && defined($password) && defined($firstName) && defined($lastName)) {
        $self->message("An email, password, first name and last name must be provided to add a user.");
        return 0;
    }

    # Create salt and encrypted password.
    my $salt;
    $salt .= sprintf("%04X", rand(0xffff)) for(1..4);
    #$salt = Crypt::Random::makerandom_octet(Length=>16);
    my $bcrypt = Digest->new('Bcrypt');
    $bcrypt->cost($COST);
    $bcrypt->salt($salt);
    $bcrypt->add($password);
    my $encPass = $bcrypt->digest();

    # Run this through quotemeta so we don't have errors inserting the encrypted 
    # password into the database.
    $encPass = quotemeta $encPass;

    # Generate a unique database name. This won't collide with another name
    # unless people with the same first name try to add a database at the 
    # same microsecond.
    (undef, my $userdb) = gettimeofday;
    $userdb = "userdb${userdb}${firstName}";

    my $dbh = $self->_getDBH();
    my $statement = "INSERT INTO users values(NULL,\"$email\",\"$encPass\",\"$salt\",NULL,1,1,0,\"$firstName\",\"$lastName\",\"$userdb\")";
    eval { $dbh->do($statement); }; 
    if($@) {
        $self->message("Failed to add user! $@");
        eval { $dbh->disconnect; };
        return 0;
    }

    $self->_initUserDB($userdb,$testuser) || do {
        eval { $dbh->do("DELETE FROM users where email=\"$email\""); };
        eval { $dbh->disconnect; };
        $self->message($self->message()." Failed to create user database! $@");
        return 0;
    };

    eval { $dbh->disconnect; };
    if($@) {
        $self->message("Failed to disconnect from the database! $@");
        return 0;
    }

    return 1;
}

sub _initUserDB {
    my $self = shift;
    my $userdb   = shift;
    my $testuser = shift;
    if(! defined($testuser)) {
         $testuser = 0;
    }

    my @tables;
    push(@tables,"CREATE TABLE $userdb.accounts (id INTEGER PRIMARY KEY AUTO_INCREMENT, acctId VARCHAR(50) NOT NULL, acctType VARCHAR(100), name VARCHAR(255), lastUpdated INTEGER, balance DECIMAL(13,2), importDate INTEGER NOT NULL,importID INTEGER NOT NULL)");
    push(@tables,"CREATE TABLE $userdb.tags (id INTEGER PRIMARY KEY AUTO_INCREMENT, name VARCHAR(255) NOT NULL, category VARCHAR(255) NOT NULL)");
    # Don't add the default tags when testing.
    if(! $testuser) {
        push(@tables,"INSERT INTO $userdb.tags SELECT * from site.tags");
    }
    push(@tables,"CREATE TABLE $userdb.todos (id INTEGER PRIMARY KEY AUTO_INCREMENT, type VARCHAR(50) NOT NULL, need VARCHAR(50) NOT NULL, given VARCHAR(255))");
    push(@tables,"CREATE TABLE $userdb.transactions (id INTEGER PRIMARY KEY AUTO_INCREMENT, acctId VARCHAR(50) NOT NULL, balance DECIMAL(13,2), amount DECIMAL(13,2), type TINYINT(1), date INTEGER, description VARCHAR(255), tag INT, importID INTEGER NOT NULL, transID VARCHAR(255) UNIQUE)");
    #id|acctID|balance|amount|type|date|description|tag|importID


    my $dbh = $self->_getDBH();
    eval { $dbh->do("CREATE DATABASE $userdb") };
    if($@) {
        $self->message("Creating user database $userdb failed!");
        goto INIT_FAIL;
    }

    foreach my $table (@tables) {
        eval { $dbh->do($table) };
        if($@) {
            $self->message("Creating user database table failed! $@ ");
            goto INIT_FAIL;
        }
    }

    eval { $dbh->disconnect; };
    if($@) {
        $self->message("Failed to disconnect from the user database! $@");
        return 0;
    }
    return 1;

    INIT_FAIL:
    eval { $dbh->disconnect; };
    return 0;
}

#####################################################################
#        Name: get
#  Parameters:     id - the user id to retrieve or 'all' for all users.
#              output - array reference to put results in if id is all.
#      Return: 1 on success, 0 on failure
# Description: Add a new user to the database.
#####################################################################
sub get {
    my $self      = shift;
    my %args      = @_;
    my $id        = $args{'id'}  || undef;
    my $output    = $args{'output'}  || undef;
    $self->message("");


    unless(defined($id)) {
        $self->message("A userid to get must be provided.");
        return 0;
    }
    if($id eq 'all' && ( ! defined($output) || ! ref $output eq 'ARRAY')) {
        $self->message("An output array reference to fill must be provided.");
        return 0;
    }

    my $dbh = $self->_getDBH();

    if($id ne 'all') {
        my $sth = $dbh->prepare("SELECT count(*) from users where id=?");
        $sth->execute($id);

        if($sth->rows()) {
            $self->id($id);    
            $self->isAuthenticated(0);
            $self->_populateFields();
            return 1;
        }
        $sth->fetchrow_arrayref;
        $sth->finish;

    } else {
        my %userData;
        $userData{'id'} = "andy";
        $userData{'firstName'} = "andy";
        $userData{'lastName'} = "andy";
        $userData{'email'} = "andy";
        $userData{'db'} = "andy";
        $userData{'role'} = "andy";
        my $sth = $dbh->prepare("SELECT id,firstName,lastName,email,db,role from users");
        eval { $sth->execute() };
        if($@) {
            $sth->finish;
            eval { $dbh->disconnect; };
            $self->message($@);
            return 0;
        }
        $sth->bind_columns(
            \$userData{'id'},
            \$userData{'firstName'},
            \$userData{'lastName'},
            \$userData{'email'},
            \$userData{'db'},
            \$userData{'role'},
         );
         while ($sth->fetch) {
             push(@$output,{%userData});
         }
        $sth->finish;

        # db email firstName id role userdb
        #push(@$output,$userData);
    }

    eval { $dbh->disconnect; };
    if($@) {
        $self->message("Failed to disconnect from the user database! $@");
        return 0;
    }
    return 1;
}
#
#####################################################################
#        Name: update
#  Parameters: data - The values to change for the user.
#      Return: 1 on success, 0 on failure
# Description: Add a new user to the database.
#####################################################################
sub update {
    my $self = shift;
    my %args = @_;
    my $id   = $self->id();
    my $data = $args{'data'}  || undef;

    unless(defined($id) && defined($data)) {
        $self->message("A user id to update and values to update must be provided.");
        return 0;
    }

    my $dbh = $self->_getDBH();

    my $statement = "UPDATE users SET ";
    foreach my $key (keys %$data) {
        $statement .= "$key=\"".$data->{$key}."\", ";
    }
    $statement .= "WHERE id=?";
    $statement =~ s/, WHERE/ WHERE/;

    my $sth;
    eval {$sth = $dbh->prepare($statement); };
    if($@) {
        $sth->finish;
        eval { $dbh->disconnect; };
        $self->message($@);
        return 0;
    }

    eval { $sth->execute($id); };
    if($@) {
        $sth->finish;
        eval { $dbh->disconnect; };
        $self->message($@);
        return 0;
    }
    $sth->finish;
    eval { $dbh->disconnect; };
    if($@) {
        $self->message("Failed to disconnect from the user database! $@");
        return 0;
    }
    return 1;
}

sub delete {
    my $self  = shift;
    my %args  = @_;
    my $email = $args{'email'} || undef;
    my $userdb;

    unless(defined($email)) {
        $self->message("An email address must be provided to delete a user.");
        return 0;
    }

    # Get the user's database name so it can be deleted.
    my $dbh = $self->_getDBH();
    my $sth = $dbh->prepare("SELECT db from users where email=?");
    $sth->execute($email);
    $sth->bind_columns(\$userdb);
    $sth->fetchrow_arrayref;
    $sth->finish;

    if(! defined($userdb) || $userdb eq '') {
        $self->message("$email is not a valid email address!");
        eval { $dbh->disconnect; };
        return 0;
    }
    my $statement =  "DELETE FROM users WHERE email=\"$email\"";
    eval { $dbh->do($statement) };
    if($@) {
        $self->message("Failed to remove user! $@");
        eval { $dbh->disconnect; };
        return 0;
    }

    eval { $dbh->do("DROP DATABASE $userdb") };
    if($@) {
        $self->message("Failed to remove the user database! $@");
        eval { $dbh->disconnect; };
        return 0;
    }

    eval { $dbh->disconnect; };
    if($@) {
        $self->message("Failed to disconnect from the user database! $@");
        return 0;
    }
    return 1;
}

sub _logLogin {
    my $self       = shift;
    my $username   = shift;
    my $ipaddr     = shift;
    my $wasSuccess = shift;

    my $dbh = $self->_getDBH();
    my $sth = $dbh->prepare("INSERT INTO logins values(NULL,?,?,?,?)");
    eval { $sth->execute($username,time(),$ipaddr,$wasSuccess) };
    if($@) {
        print "Failed to log login attempt! $@";
    }

    eval { $sth->finish; };
    eval { $dbh->disconnect; };
    return 1;
};

1;
