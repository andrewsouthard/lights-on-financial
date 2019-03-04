echo off 
REM Clean up
rm -rf bin/

REM Download cpanm and install Perl libraries
curl -LOk http://xrl.us/cpanm
chmod +x cpanm
cpanm -n -L . Class::Tiny DBD::SQLite Excel::Writer::XLSX DateTime JSON Email::Stuffer DBI Text::CSV File::Basename File::Spec

REM Setup Finance::OFX::Parse::Simple
set OFX_DIR="lib/perl5/Finance/OFX/Parse/"
mkdir -p %%OFX_DIR
copy Simple.pm %%OFX_DIR
rm -rf bin/ cpanm
