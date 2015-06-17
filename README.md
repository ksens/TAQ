# Example SciDB queries for trade and quote data

You will need the following plugins to run all the examples here:

* load_tools (https://github.com/paradigm4/load_tools)
* cu (https://github.com/paradigm4/chunk_unique)
* linear_algebra (part of Paradigm4 enterprise plugins, contact Paradigm4)

## Obtain example data

The example queries here use the following example data obtained from Nyxdata:

```
wget ftp://ftp.nyxdata.com/Historical%20Data%20Samples/Daily%20TAQ/EQY_US_ALL_NBBO_20131218.zip
wget ftp://ftp.nyxdata.com/Historical%20Data%20Samples/Daily%20TAQ/EQY_US_ALL_TRADE_20131218.zip
```

The example data file format specification is available from:
`http://www.nyxdata.com/doc/224904`


## Loading the data into ScIDB

The trades_load.sh and trades_redim.sh scripts load the
EQY_US_ALL_TRADE_20131218.zip data and redimension them into a ms (time) by
symbol_index 2-d SciDB array. The script also creates an auxiliary mapping
array named 'tkr' between string ticker symbol and integer symbol index.

The quotes_load.sh and quotes_redim.sh script does the same thing but for the
EQY_US_ALL_NBBO quote data file.

Run the following to load and redimension the example data

```
./trades_load.sh
./trades_redim.sh

./quotes_load.sh
./quotes_redim.sh
```

## Looking up trades by symbol string

Join with the auxiliary `tkr` array to look up data by ticker symbol name.
Here are examples that count the number of trades and quotes for 'BAM'.

```
iquery -aq "
op_count(
  cross_join(trades as x, filter(tkr, symbol='BAM') as y, x.symbol_index, y.symbol_index)
)"

## {i} count
## {0} 6337

iquery -aq "
op_count(
  cross_join(quotes as x, filter(tkr, symbol='BAM') as y, x.symbol_index, y.symbol_index)
)"

## {i} count
## {0} 49667
```

As expected we see more quotes than trades for this instrument. Note that you can
also just filter directly by symbol index using `between` if you know it. For example:

```
iquery -aq "filter(tkr, symbol='BAM')"

## {symbol_index} symbol
## {615} 'BAM'


iquery -aq "
op_count(
   between(trades, null,615,0, null,615,null)
)"

## {i} count
## {0} 6337
```

## Inexact time join with last-value imputation

The `last_value_join.sh` script generates an example query that joins trade
data with quote data. At time points where quote data is not available, the
last known value is looked up and filled in. This is sometimes called an
'as.of' join or 'last value carry forward' join.

The syntax is
```
./last_value_join.sh  "quote array or expression"  "trade array or expression"
```
and the script returns a _query_ which you can then run.

Here is an example that joins trades and quotes for 'BAM'. We use the fact
that we know the symbol index for BAM is 615 from the last example.

```
x=$(./last_value_join.sh "between(quotes, null,615,0, null,615,null)" "between(trades, null,615,0, null,615,null)")

# Count the result
iquery -aq "op_count($x)"

## {i} count
## {0} 


# Note that it matches the trades array expression count
iquery -aq "op_count(between_trades(null,615,0, null,615,null)"

## {i} count
## {0} 6337

# Show just part of the result
iquery -aq "$x" | head

## {symbol_index,ms} ask_price,ask_size,bid_price,bid_size,sequence_number,price,volume,sequence_number
## {615,34185171} 41.6,6,37.8,3,300537,38.9,91,3309
## {615,34185172} 41.6,6,37.8,3,300537,39,100,3310
## {615,34185173} 41.6,6,37.8,3,300537,38.8,91,3312
## {615,34185950} 42,1,37.8,3,300938,38.8,9,3313
## {615,34200381} 40.1,1,37,1,305290,39.8,9761,3695
## {615,34200429} 40.1,1,39.2,3,305901,39.2,100,3742
## {615,34201201} 40.1,1,38.6,1,309302,38.9,100,3899
## {615,34201215} 40.1,1,38.4,1,309342,38.8,100,3906
## {615,34201216} 40.1,1,38.4,1,309342,38.8,100,3907
```

If you want, you can examine the actual query in the last example with `echo $x`. It's pretty complicated.
See the detailed comments in the `last_value_join.sh` file itself for help on how the query works.


## Bar-building

See detailed comments and examples in the trades_bars.sh script.
