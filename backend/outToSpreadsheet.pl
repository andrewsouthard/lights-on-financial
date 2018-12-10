#!/usr/bin/perl
use strict;
use warnings;

# FinancialModern libraries.
use lib ".";
use parent 'FinancialModern';

use DBI;
use Class::Tiny qw(db message);
use Excel::Writer::XLSX;
use File::Basename;
use File::Spec;
use POSIX 'strftime';
use Time::Local;

my $self  = {};
bless $self,"";
my $database = $ARGV[0];
if(! -e $database) {
        print "Database does not exist!\n";
        exit 1;
}
$self->db($database);
my $dbh = $self->_getDBH();

my $sth  = $dbh->prepare('select min(date),max(date) from transactions');
eval { $sth->execute() };
if($@) {
    print "Querying the accounts failed! $@";
    exit 1;
}

my @row = $sth->fetchrow_array;
my $minDate = $row[0];
my $maxDate = $row[1];
my $startMon = strftime("%m",localtime($minDate));
my $startYear = strftime("%Y",localtime($minDate));
my $endMon = strftime("%m",localtime($maxDate));
my $endYear = strftime("%Y",localtime($maxDate));

$sth->finish();

my $accounts = mapAccountNames($dbh);
my $spreadsheetName = 'budget-sheet.xlsx';
if(defined $ARGV[1]) {
	$spreadsheetName = $ARGV[1];
}

# The spreadsheet will be placed in the same directory as the database.
my $outputPath = File::Spec->catfile(dirname($database),$spreadsheetName);

my $workbook  = Excel::Writer::XLSX->new($outputPath);
unless(defined $workbook) {
print "ERROR $@!\n";
exit 1;
}

# Setup formats
my $currencyFormat = $workbook->add_format();
#XXX: Need to localize this.
$currencyFormat->set_num_format('$0.00');
$currencyFormat->set_align('center');
my $centerFormat = $workbook->add_format();
$centerFormat->set_align('center');
my $headerFormat = $workbook->add_format();
$headerFormat->set_align('center');
$headerFormat->set_bold();
my $rightBold = $workbook->add_format();
$rightBold->set_align('right');
$rightBold->set_bold();


my $currentMon = $startMon;
my $currentYear = $startYear;
my @months = ('January','February','March','April','May','June','July','August','September','October','November','December');

my %transactions;
while($currentYear < $endYear || ($currentYear == $endYear && $endMon >= $currentMon)) {
    print "Parsing $currentMon $currentYear\n";
    # Get the epoch for the first and last seconds of the month.
    my $firstDayEpoch = timelocal(0,0,0,1,$currentMon - 1,$currentYear);
    my @info = ($currentMon == 12) ? (0,$currentYear+1) : ($currentMon,$currentYear);
    my $lastDayEpoch = timelocal(59,59,23,1,@info);
    $lastDayEpoch -= 86400;

    my $statement = "select acctId, amount, type, date, description,category from transactions where date between $firstDayEpoch and $lastDayEpoch order by date";
    my $sth  = $dbh->prepare($statement);
    eval { $sth->execute() };
    if($@) {
        print "Error while querying transactions! $@\n";
        last;
    }
    my $transKey = sprintf("%02d-%02d",$currentYear,$currentMon);
    $transactions{$transKey} = ();
    my $transList = [];
    # Convert each row to what we want in the spreadsheet.
    # @trans ends up being: acctId,date,amount,desc,category
    while(my @row = $sth->fetchrow_array) {
        my @trans = ();
        push(@trans,$accounts->{$row[0]});
        push(@trans,strftime("%m-%d-%Y",localtime($row[3])));

        if($row[2] == 0) {
            push(@trans,sprintf("-%.2f",$row[1]));
        } else {
            push(@trans,sprintf("%.2f",$row[1]));
        }
        push(@trans,$row[4]);
        push(@trans,$row[5]);
        push(@$transList,\@trans);
    }
    $transactions{$transKey} = $transList;

    # Increment
    if($currentMon == 12) {
        $currentYear++;
        $currentMon = 1;
    } else {
        $currentMon++;
    }
}
my $categories = [
    'Clothing',
    'Donations',
    'Education',
    'Food',
    'Gifts',
    'Healthcare',
    'Housing/Household',
    'Media & Entertainment',
    'Miscellaneous',
    'Subscriptions/Memberships',
    'Taxes',
    'Transportation',
    'Utilities',
    'Vacation',
    ];
my $incomeCategories = [
    'Salary',
    'Interest',
    'Investments',
];

# Define the months for each year that should have data.
my %overviewInfo;
foreach my $key (sort keys(%transactions)) {
    (my $y,my $m) = split("-",$key);
    if(exists $overviewInfo{$y}) {
        push(@{$overviewInfo{$y}},$months[$m-1]);
    } else {
        $overviewInfo{$y}[0] = $months[$m-1];
    }
}

my $catFirstRow = 4;
my $catLastRow = scalar(@$categories) - 1 + $catFirstRow;
my $incomeCatFirstRow = $catLastRow + 3;
my $incomeCatLastRow = $incomeCatFirstRow + scalar(@$incomeCategories) -1;

# Create an overview sheet for each year
foreach my $year (sort keys %overviewInfo) {
    my $sheet = "$year Overview";
    my $worksheet = $workbook->add_worksheet($sheet);

    # Setup the title columns
    my @overviewTitle = ('Category');
    push(@overviewTitle,@{$overviewInfo{$year}});
    push(@overviewTitle,'Totals');
    $worksheet->write_row(1,0,\@overviewTitle,$headerFormat);
    $worksheet->set_column(0,scalar(@overviewTitle)-1,15);

    # Add a title to the sheet so it's evident what's going on.
    $worksheet->merge_range(0, 0, 0, scalar(@overviewTitle)-1, $sheet, $headerFormat);


    # Create the formulas for each month's data by category.
    my $monCol = 1;
    my @letters = 'A' .. 'Z';
    my $numCategories = scalar(@$categories);
    my $numIncomeCategories = scalar(@$incomeCategories);
    my $startIncomeRow = $numCategories + 2;

    # Add the list of categories
    $worksheet->write_col(2,0,$categories);
    $worksheet->write(scalar(@$categories)+2,0,'Totals',$rightBold);
    # Add the list of income categories
    $worksheet->write_col($startIncomeRow+2,0,$incomeCategories);
    $worksheet->write($startIncomeRow+$numIncomeCategories+2,0,'Totals',$rightBold);

    foreach my $month (@{$overviewInfo{$year}}) {
        my $categorySums = [];
        for(my $i = 0; $i < $numCategories ; $i++) {
            push(@$categorySums,"='$year-$month'!H".($i+$catFirstRow+1));
        }
        my $currLetter = $letters[$monCol];
        push(@$categorySums,"=SUM(${currLetter}2:$currLetter".($numCategories+2).")");
        $worksheet->write_col(2,$monCol,$categorySums,$currencyFormat);

        my $incomeSums = [];
        for(my $i = 0; $i < scalar(@$incomeCategories); $i++) {
            push(@$incomeSums,"='$year-$month'!H".($i+$incomeCatFirstRow+1));
        }
        push(@$incomeSums,"=SUM(${currLetter}".($startIncomeRow+3).":$currLetter".($startIncomeRow+$numIncomeCategories+2).")");
        $worksheet->write_col($startIncomeRow+2,$monCol,$incomeSums,$currencyFormat);
        $monCol++;
    }
    # Add a yearly total column.
    for(my $c = 0; $c < $numCategories; $c++) {
        $worksheet->write($c+2,$monCol,"=SUM(".$letters[1].($c+3).":".$letters[$monCol-1].($c+3).")",$currencyFormat);
    }
    my $currLetter = $letters[$monCol];
    $worksheet->write($numCategories+2,$monCol,"=SUM(${currLetter}2:${currLetter}".($numCategories+2).")",$currencyFormat);

    # Sum all the income by month.
    my $incomeCol = scalar(@$categories)+5;
    for(my $c = 0; $c < $numIncomeCategories; $c++) {
        $worksheet->write($c+$incomeCol-1,$monCol,"=SUM(".$letters[1].($incomeCol+$c).":".$letters[$monCol-1].($c+$incomeCol).")",$currencyFormat);
    }
    # Write the sum total of all income for the year
    $worksheet->write($incomeCol+$numIncomeCategories-1,$monCol,"=SUM(${currLetter}".($incomeCol).":${currLetter}".($incomeCol + $numIncomeCategories -1).")",$currencyFormat);

    # Add a stacked area chart of spending by month.
    my $areaChart = $workbook->add_chart( type => 'area', subtype => 'stacked', embedded => 1);
    $areaChart->set_x_axis( name => 'Month' );
    #XXX: Need to localize this.
    $areaChart->set_y_axis( name => 'Spending', num_format => '$0.00' );

    # Add a series for each category
    my $catRow = 2;
    foreach my $category (@$categories) {
        # Configure the series. Note the use of the array ref to define ranges:
        # [ $sheetname, $row_start, $row_end, $col_start, $col_end ].
        $areaChart->add_series(
           name       => $category,
           categories => [ $sheet, 1, 1 , 1, $monCol-1 ],
           values     => [ $sheet, $catRow, $catRow, 1, $monCol -1],
        );
        $catRow++;
    }

    # Set an Excel chart style.
    $areaChart->set_style(10);
    $areaChart->set_title(name => "$year Spending");
    $worksheet->insert_chart(1,$monCol+2,$areaChart);
}
my @transactionTitle = ('Account Name','Date','Amount','Description','Category','','Income','Expenditures');
foreach my $key (sort keys(%transactions)) {
    my $categorySums = [];
    my $incomeSums = [];
    my $transLastCell = scalar(@{$transactions{$key}})+1;
    for(my $i=0; $i < scalar(@$categories); $i++) {
        push(@$categorySums,"=ABS(SUMIF(E\$2:E\$$transLastCell,G".($i+$catFirstRow+1).",C\$2:C\$$transLastCell))");
    }
    for(my $i=0; $i < scalar(@$incomeCategories); $i++) {
        push(@$incomeSums,"=ABS(SUMIF(E\$2:E\$$transLastCell,G".($i+$incomeCatFirstRow+1).",C\$2:C\$$transLastCell))");
    }

    (my $year,my $month) = split("-",$key);
    my $sheet = sprintf("%d-%s",$year,$months[$month-1]);
    my $worksheet = $workbook->add_worksheet($sheet);
    $worksheet->write_row(0,0,\@transactionTitle,$headerFormat);
    $worksheet->write_col(1,0,$transactions{$key});
    
    # Add the income and expenditure totals..
    $worksheet->write_row(1,6,["=SUM(H".($incomeCatFirstRow+1).":H".($incomeCatLastRow+1).")","=SUM(H".($catFirstRow+1).":H".($catLastRow+1).')'],$currencyFormat);

    # Add spending titles and data.
    $worksheet->merge_range(3,6,3,7,['Monthly Expenditures'],$headerFormat);
    $worksheet->write_col(4,6,$categories);
    $worksheet->write_col(4,7,$categorySums,$currencyFormat);

    # Set column width.
    $worksheet->set_column(0,0,20);
    $worksheet->set_column(1,2,15,$centerFormat);
    $worksheet->set_column(3,4,30);
    $worksheet->set_column(2,2,undef,$currencyFormat);
    $worksheet->set_column(6,7,30);

    # Add income categories and data.
    $worksheet->merge_range($incomeCatFirstRow-1,6,$incomeCatFirstRow-1,7,['Monthly Income'],$headerFormat);
    $worksheet->write_col($incomeCatFirstRow,6,$incomeCategories);
    $worksheet->write_col($incomeCatFirstRow,7,$incomeSums,$currencyFormat);

    # Add a pie chart
    my $pieChart = $workbook->add_chart( type => 'pie', embedded => 1);

    # Configure the series. Note the use of the array ref to define ranges:
    # [ $sheetname, $row_start, $row_end, $col_start, $col_end ].
    $pieChart->add_series(
        name       => $months[$month-1]." $year Spending",
        categories => [ $sheet, $catFirstRow, $catLastRow, 6, 6 ],
        values     => [ $sheet, $catFirstRow, $catLastRow, 7, 7],
        data_labels => { percentage => 1, leader_lines => 1 },
        font  => { bold => 1 },
    );
    $pieChart->set_style( 10 );
    $pieChart->set_title(name => $months[$month-1]." $year Spending");
    $worksheet->insert_chart($incomeCatLastRow+2,6,$pieChart);
}
$dbh->disconnect();

# Tranform each word to have the first letter capitalized and all others
# lowercase.
sub wordTransform {
    my $w = shift;
    $w =~ s/(.){1}(.*)/uc($1).lc($2)/ge;
    return $w;
}

# Map account ids to names. If two accounts have the same name, append the
# account type to the name to differentiate. This can happen if more than one
# account's information is in the same file.
sub mapAccountNames {
    my $dbh = shift;
    my $statement = "select distinct acctID, acctType, name from accounts";
    my $sth  = $dbh->prepare($statement);
    eval { $sth->execute() };
    if($@) {
        print "Error while querying accounts! $@\n";
        return undef;
    }
    my $results =  $sth->fetchall_hashref('acctId');
    my @accts = map { $results->{$_} } keys %$results;
    $sth->finish();

    my %accounts;
    foreach my $acct (@accts) {
       if(scalar values %accounts && grep(/^$acct->{'name'}$/,values %accounts)) {
           foreach my $key (keys %accounts) {
               next if($accounts{$key} ne $acct->{'name'});
               $accounts{$key} = $acct->{'name'}." ".wordTransform($results->{$key}->{'acctType'});
           }
           $accounts{$acct->{'acctId'}} = $acct->{'name'}." ".wordTransform($results->{$acct->{'acctId'}}->{'acctType'});
       } else {
           $accounts{$acct->{'acctId'}} = $acct->{'name'};
       }
    }
    return \%accounts;
}
