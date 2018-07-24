# Lights On Financial

Lights on Financial is a cross platform desktop app that creates a spreadsheet
of your cash flow from QFX, OFX or CSV files provided by your financial
institutions. We don't ask for your bank passwords or and all of your
information is stored locally and never leaves your computer.



**Installation**
-----------------------------

1. Clone the repository
2. If necessary, install [NodeJS](https://nodejs.org/en/) and then yarn.
```
$ sudo npm i -g yarn
```
3. 	If necessary, install Perl 5.8 or greater. Mac OS X and Linux users should have Perl installed by default. For Windows users we recommend [Strawberry
Perl](http://strawberryperl.com)
4. 	Start Lights On Financial.
```
$ yarn start
```

**Using Lights On Financial**
-------------
Your financial institutions should provide a way to export or download your transaction history. Use this option to download in either QFX,OFX or CSV format. If multiple options are available, usually QFX/OFX are the most reliable. 

Once these files are downloaded, open Lights On Financial and import each file. After all the files have been imported, create the spreadsheet.

**Contributing**
----------------

Feel free to open an issue or make a pull request for any bug fixes or features.



**License**
-----------

This project it covered by the MIT License. See the LICENSE file for more
information.
