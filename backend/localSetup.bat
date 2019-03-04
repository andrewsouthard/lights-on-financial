echo off 

cd backend

REM Clean up
rm -rf bin/


REM Download cpanm and install Perl libraries
curl -L http://xrl.us/cpanm > cpanm
chmod +x cpanm
.\cpanm -n -L . Class::Tiny DBD::SQLite Excel::Writer::XLSX DateTime JSON Email::Stuffer DBI Text::CSV File::Basename File::Spec

REM Setup Finance::OFX::Parse::Simple

mkdir -p "lib/perl5/Finance/OFX/Parse/"
copy Simple.pm lib/perl5/Finance/OFX/Parse/
rm -rf bin/ cpanm
