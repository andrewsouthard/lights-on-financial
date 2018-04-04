#!/bin/bash

if which yum > /dev/null; then
    yum install -y perl-DBD-SQLite perl-Excel-Writer-XLSX
else
    apt-get install build-essential libmysqlclient-dev
fi
