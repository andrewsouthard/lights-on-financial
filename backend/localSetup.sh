#!/bin/bash

BACKENDDIR=$(dirname $(readlink -f ${BASH_SOURCE[0]} ))
CLEAN=0
PREPARE_FOR_PACKAGING=1

if [[ $CLEAN -eq 1 ]]; then
    cd $BACKENDDIR
    rm -rf bin/ lib/
fi

if [[ ! -f ./cpanm ]]; then
    curl -LOk http://xrl.us/cpanm
    chmod +x cpanm
fi
INSTALL_CMD="./cpanm -L ./"

for pkg in Class::Tiny DBD::SQLite Excel::Writer::XLSX DateTime JSON Email::Stuffer DBI Text::CSV File::Basename File::Spec
do
    $INSTALL_CMD $pkg
done

# Setup Finance::OFX::Parse::Simple
OFX_DIR="lib/perl5/Finance/OFX/Parse/"
if [[ ! -f $OFX_DIR ]]; then 
    mkdir -p $OFX_DIR
    cp Simple.pm $OFX_DIR
fi

if [[ $PREPARE_FOR_PACKAGING -eq 1 ]]; then
    cd $BACKENDDIR
    rm -rf bin/ cpanm
fi
