use strict;
use warnings;

package FinancialModern::Import;

use lib '.';
use lib './lib/perl5/';
use parent 'FinancialModern';
use Class::Tiny qw(db message token user);
use FinancialModern::UserDatabase;

use DBI;
use Date::Parse;
use FileHandle;
use Finance::OFX::Parse::Simple;
use Text::CSV;
use Time::HiRes qw(gettimeofday);
use Time::Local;

# Don't warn about smart matching being experimental.
no if ($] >= 5.018), 'warnings' => 'experimental';
use feature "switch";

#####################################################################
#        Name: new
#  Parameters: user - a FinancialModern::User object.
#      Return: self
# Description: Instantiate a new object.
#####################################################################
sub new {
    my $class  = shift;
    my $db = shift;

#   return undef if(! defined($user));

    # Instantiate.
    my $self  = {};
    bless $self,$class;

    if(defined($db)) {
        $self->db($db);
    }

    # Save the user instance.
#   $self->user($user);
    return $self;
}

#####################################################################
#        Name: importOFX
#  Parameters: data - a string of OFX data.
#      Return: 1 on success, 0 on failure.
# Description: 
#####################################################################
sub importOFX {
    my $self = shift;
    my $filename = shift;
    my $acctName = shift;
    $self->message('');

    # Verify $filename exists
    if(! -f $filename) {
        $self->message("File $filename does not exist!");
        return 0;
    }

    my $file = FileHandle->new($filename);
    my @contentsArray = $file->getlines();
    $file->close();
    my $fileContents  = join("",@contentsArray);

    # Instantiate a parser object
    my $parser = Finance::OFX::Parse::Simple->new();
    my $ofx = $parser->parse_scalar($fileContents);
    if(ref $ofx ne 'ARRAY') {
        $self->message("Error processing OFX file!");
        return 0;
    }
    return $self->parseIntoDatabase($ofx,$acctName);
}

sub parseIntoDatabase {
    my $self = shift;
    my $accounts = shift;
    my $acctName = shift;

    # Get the epoch in microseconds. This is used to tag this import transaction
    # so it can be removed if necessary.
    (undef, my $importID) = gettimeofday;

    my $acctNum  = undef;
    my $routing  = undef;
    my $acctType = undef;
    my $date  = undef;

    my $userDB = FinancialModern::UserDatabase->new($self->db);

    my @transactionsToAdd;
    my $transactionsAdded = 0;

    foreach my $account (@$accounts) {
        $acctNum  = $account->{account_id};
        # Remove any special characters from the acct ID
        $acctNum  =~ s/[^a-zA-Z0-9]*//g;
        $routing  = $account->{bank_id};
        $acctType = $account->{acct_type};
        my $balance_info = $account->{balance_info};
        my $balance      = $balance_info->{'balance'};
        $date  = $balance_info->{'date'};
        my $name = "";



        # See if the account exists.
        my $acct = FinancialModern::Account->new();
        $acct->routing($routing);
        $acct->acctNum($acctNum);
        $acct->_genAcctID();
 
        my $result = $userDB->get('item' => $acct);
        if(! defined($result) || scalar @$result == 0) {
            $acct->name($acctName);
        } else {
            $acct->name($result->[0]->name);
        }

        $acct->acctType($acctType);
        $acct->balance($balance);
        $acct->importID($importID);
        
        # Convert the date string in the format of yyyymmddHHMM into epoch. The
        # exact hour, minute and second aren't present/important so just put in 0s.
        my @dateStr = ( $date =~ m/\d\d/g );
        my $year = $dateStr[0].$dateStr[1];
        # Subtract 1 from the month since the function expects a month range 
        # from 0-11.
        $acct->lastUpdated(timelocal(0,0,0,$dateStr[3],$dateStr[2] - 1,$year));

        # Verify and add the account entry.
        $acct->verify() || do {
            $self->message("Error verifying account! ".$acct->message());
            return 0;
        };

        $userDB->add($acct) || do {
            $self->message("Error adding account ".$userDB->message());
            return 0;
        };

        # Create an array of transactions from most recent to least recent. Do it this
        # way so the account balance can be easily calculated.
        #use Data::Dumper;
        #print Dumper($account->{transactions});
        my @sortedTrans = reverse sort { join("",split("-",$a->{'date'})) cmp join("",split("-",$b->{'date'}))} @{$account->{transactions}};

        print "Parsing ".scalar(@sortedTrans)." transactions\n";

        # Parse each transaction.
        foreach my $line (@sortedTrans) {
            my $transaction = FinancialModern::Transaction->new();
            my $date = $line->{'date'};
            # Convert to epoch.
            $transaction->date(str2time($date));
            my $type = ($line->{'trntype'} ne 'CREDIT' ? 0 : 1);
            $transaction->type($type);
            if($line->{'name'} eq '') {
                $transaction->description($line->{'trntype'});
            } else {
                $transaction->description($line->{'name'});
            }
            (my $amount = $line->{'amount'}) =~ s/-(.*)/$1/;
            $amount =~ s/,//;
            $transaction->amount($amount);
            $transaction->acctID($acct->acctID);
            $transaction->balance($balance);
            $transaction->importID($importID);
            $userDB->add($transaction) || do {
                $self->message("Failed to add transaction! ".$userDB->message());
                return 0;
                
            };
            #
            # Calculate and set the balance for the next transaction.
            if($type) {
                $balance -= $amount;
            } else {
                $balance += $amount;
            }
            $transactionsAdded++;
        }
    }

    $self->message("$transactionsAdded transactions imported successfully!");
    return 1;
}
# Determine the columns in a CSV file.
sub determineColumns {
    my $self = shift;
    my $line = shift;
    my $delimiter = shift;
    my @csvFields = split($delimiter,$line);
    my @fields;
    my $minFields = 0;

    foreach my $f (@csvFields) {
        (my $name = $f) =~ s/\s+/_/g;
        given($f) {
            when (/date/i) {
                my $matches = grep(/date/i,@csvFields);
                if($matches == 1) {
                    push(@fields,'Transaction_Date');
                } elsif($f =~ /trans.*date/i) {
                    push(@fields,'Transaction_Date');
                } else {
                    push(@fields,$name);
                }
                $minFields++;
            }
            when (/description/i) { push(@fields,'Transaction_Description'); $minFields++; }
            when (/credit/i) { push(@fields,'Credit'); $minFields++; }
            when (/debit/i) { push(@fields,'Debit'); $minFields++; }
            when (/amount/i) { push(@fields,'Amount'); $minFields++; }
            when (/(?<!account)\s*type/i) { push(@fields,'Transaction_Type') }
            when (/account.*type/i) { push(@fields,'Account_Type') }
            when (/bank.*id/i) { push(@fields,'Bank_ID') }
            # The default is to replace any spaces in the name with underscores
            # and use that since nothing else matched.
            default { push(@fields,$name); }
        }
    }
    if($minFields < 3) {
        return undef;
    } else {
        return \@fields;
    }
}

sub importCSV {
    my $self = shift;
    my $file = shift;
    my $acctName = shift;
    $self->message('');

    unless(defined($file)) {
        return 'File not defined!';
    }

    my $fh = FileHandle->new("< $file");
    unless(defined($fh)) {
        return "Couldn't open file!";
    }

    # Get the first line of the file. This should be the column labels.
    my @line = $fh->getline();

    # If the file starts with blank lines, skip them and get to the column
    # labels.
    while(join("",@line) =~ /^\s*$/) {
        @line = $fh->getline();
    }

    # Define the delimiter this way in case we ever want to support others.
    my $delimiter = ',';

    # Do our best to match the columns in the file to the data we need.
    my $fields = $self->determineColumns("@line",$delimiter);
    unless(defined $fields) {
        return "Could not determine the fields of the CSV file!";
    }


    my $csv = Text::CSV->new({'sep_char' => $delimiter}) || do {
        return Text::CSV->error_diag();
    };

    $csv->column_names(@$fields);
    my $lines = $csv->getline_hr_all($fh);

    my $acctNum = 0;
    my $acctDate;
    my $acctType = 'CHECKING';
    my $balance = 0;
    my $bankID = time;
    my $lineNum = 0;
    my @transactions;
    foreach my $line (@$lines) {
        $lineNum++;
        my $amount;
        my $transType;

        # Process the transaction.
        my $transDesc = $line->{'Transaction_Description'};

        # There are two main ways CSV files maintain amount and transaction
        # type information. They either have a column for debits and another
        # for credits or have a column for the transaction amount and anther
        # for the transaction type.
        if(grep(/Credit/,@$fields)) {
            if($line->{'Credit'} =~ /\d/) {
                $amount = $line->{'Credit'};
                $transType = "CREDIT";
            } else {
                $amount = $line->{'Debit'};
                $transType = "DEBIT";
            }
        } else {
            # Take the negative sign off of the front of the amount if it's there.
            ($amount = $line->{'Amount'}) =~ s/-(.*)/$1/;
            $amount =~ s/,//;

            # Do our best to figure out the type of the transactions.
            if($line->{'Transaction_Type'} =~ /(credit|deposit)/i) {
                $transType = 'CREDIT';
            } elsif($line->{'Transaction_Type'} =~ /(debit|withdrawl)/i) {
                $transType = 'DEBIT';
            }
        }

        # Format the date to match my standard of YYYYMMDD.
        (my $date = $line->{'Transaction_Date'}) =~ s/-//g;
        if($date =~ m/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/) {
            $date =~ s/^(\d{1})\/(\d{1})\/(\d{4})/${3}0${1}0${2}/;
            $date =~ s/^(\d{1})\/(\d{2})\/(\d{4})/${3}0${1}${2}/;
            $date =~ s/^(\d{2})\/(\d{1})\/(\d{4})/${3}${1}0${2}/;
            $date =~ s/^(\d{2})\/(\d{2})\/(\d{4})/${3}${1}${2}/;
        }

        # If this is the last line in the CSV file, get any account information
        # present here that we can use.
        if($lineNum +1 == scalar @$lines) {
            if(@$fields ~~ 'Account_Number') {
                $acctNum = $line->{'Account_Number'};
            }
            if(@$fields ~~ 'Account_Type') {
                $acctType = $line->{'Account_Type'};
            }
            if(@$fields ~~ 'Balance') {
                $balance = $line->{'Balance'};
            }
            if(@$fields ~~ 'Bank_ID') {
                $bankID = $line->{'Bank_ID'};
            }
            $acctDate = $date;
        }

        # Define the transaction and add it to the array.
        my $trans = {
            'name' => $transDesc,
            'date' => $date,
            'trntype' => $transType,
            'amount' => $amount,
        };
        push(@transactions,$trans);
    }
    my $accounts = [{
            'account_id' => $acctNum,
            'transactions' => \@transactions,
            'acct_type' => $acctType,
            'balance_info' => {
                'date' => $acctDate,
                'balance' => $balance,
            },
            'bank_id' => $bankID,
        }];
    return $self->parseIntoDatabase($accounts,$acctName);
}

1;
