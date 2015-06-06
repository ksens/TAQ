Example data files (you'll need to download these):

ftp://ftp.nyxdata.com/Historical%20Data%20Samples/Daily%20TAQ/EQY_US_ALL_NBBO_20131218.zip
ftp://ftp.nyxdata.com/Historical%20Data%20Samples/Daily%20TAQ/EQY_US_ALL_TRADE_20131218.zip

Data file format specification:

file:///home/chronos/u-699d3583be3ebd1830bdb917dfef0b776daa6b47/Downloads/Daily_TAQ_Client_Spec_v2%200.pdf



Loading the data

The trades_load.sh and trades_redim.sh scripts load the
EQY_US_ALL_TRADE_20131218.zip data and redimension them into a ms (time) by
symbol_index 2-d SciDB array. The script also creates an auxilliary mapping
array named 'tkr' between string ticker symbol and integer symbol index.

The quotes_load.sh and quotes_redim.sh script does the same thing but for the
EQY_US_ALL_NBBO quote data file.


Run the following to load and redimension the example data

./trades_load.sh
./trades_redim.sh

./quotes_load.sh
./quotes_redim.sh

