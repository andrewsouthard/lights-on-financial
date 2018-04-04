#!/bin/bash

if [[ ! -f ./cpanm ]]; then
    curl -LOk http://xrl.us/cpanm
    chmod +x cpanm
fi
INSTALL_CMD="./cpanm -L ./"

for pkg in Class::Tiny DBD::mysql DBD::SQLite Excel::Writer::XLSX DateTime JSON Email::Stuffer DBI Text::CSV
do
    $INSTALL_CMD $pkg
done

# Setup Finance::OFX::Parse::Simple
OFX_DIR="lib/perl5/Finance/OFX/Parse/"
if [[ ! -f $OFX_DIR ]]; then 
    mkdir -p $OFX_DIR
    cp Simple.pm $OFX_DIR
fi
