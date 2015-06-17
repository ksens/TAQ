# Example SciDB queries for trade and quote data

You will need the following plugins to run all the examples here:

* load_tools (https://github.com/paradigm4/load_tools)
* cu (https://github.com/paradigm4/chunk_unique)
* linear_algebra (part of Paradigm4 enterprise plugins, contact Paradigm4)
* openclose (contact Paradigm4)

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

## Computing minute bars

The trade data are now organized by symbol, time, and a dummy coordinate that
separates collisions (due to, say exchanges)  in a sparse array.

The following query computes and store one-minute open/high/low/close bars from
these data. We need some extra aggregates from the openclose plugin:
load that:
```
iquery -naq "load_library('openclose')"
iquery -naq "
store(
  slice(
    regrid(trades, 1000, 1, 60000,
           open(price) as open,
           max(price) as high,
           min(price) as low,
           close(price) as close),
  dummy,0),
minute_bars)"
```

This query runs in seconds, even on modest desktop machines. It
produces one-minute bars for _all_ stock trade data at once.

Let's deconstruct the query:

`regrid(trades, 1000, 1, 60000, ...)` applies the open/high/low/close summary
statistics over regular rectilinear regions along the coordinate axes.  The
rectangles have dimension 1000 (dummy) by 1 (symbol) by 60000 milliseconds.
That means we compute the open/high/low/close price over all sequence numbers
for each symbol per one minute.

`slice(..., dummy ,0)` removes the dummy (sequence number_ coordinate axis from
 the result. It's no longer needed because all trades for each symbol and
 minute have been accounted for in the regrid aggregate. So slice simply
 removes this no longer used axis.

We're left with an array named 'minute_bars' that has two dimensions:
symbol_index and 60000 ms (that is, minutes). The array is still sparse
beause some thinly traded instruments may not have had any trades in some of
the minute intervals.


Let's pull out one of these minute bar time series for a particuar stock,
CVS.  We can consult the symbols array to find it's index directly.
```
iquery -aq "filter(apply(trade_symbols,x,regex(symbol, 'CVS')), x=true)"
# {i} symbol,x
# {1612} 'CVS',true
```
So this says that symbol index 1612 corresponds to CVS.

We can  use SciDB's cross_join to avoid an explicit index lookup. We do need
to use a repart to bring the symbols array schema into a conformable chunking
scheme with the minute_bars array. Only the first 10 minutes of bars are
shown below:

```
iquery -aq "
cross_join(
  minute_bars as A,
    project(
      filter(apply(tkr,x,regex(symbol, 'CVS')), x=true),symbol) as B,
  A.symbol_index, B.symbol_index)" | head -n 10

# {symbol_index,ms} open,high,low,close,symbol
# {1612,513} 72,72,67.1,67.1,'CVS'
# {1612,560} 70.1,70.1,70.1,70.1,'CVS'
# {1612,561} 70.1,70.2,70.1,70.2,'CVS'
# {1612,563} 70.2,70.2,70.2,70.2,'CVS'
# {1612,565} 70.2,70.2,70.2,70.2,'CVS'
# {1612,568} 70.2,70.2,70.2,70.2,'CVS'
# {1612,569} 70.2,72.4,70.2,72.4,'CVS'
# {1612,570} 68.2,73.7,68.2,72.2,'CVS'
# {1612,571} 69.75,76.9,68,71.1,'CVS'
```
Note! That  570 minutes = 9:30 AM.



## Computing VWAP for all trades

Let's turn to another common kind of operation, computing volume-weighted
average price (VWAP). We'll compute it for every instrument across their raw
trade data in the array tades, and store the result into a new array called
'VWAP'.
```
iquery -naq "
store(
  apply(
    cumulate(
      apply(trades, pv, price*volume),
      sum(pv) as numerator,
      sum(volume) as denominator, ms),
    vwap, numerator/denominator),
  VWAP)"
```

This query runs pretty quickly even on modest hardware. It computes and stores
vwap on the millisecond data for all instruments. Here is a brief overview of
each step:

- `apply(trades, pv, price*volume)` adds a new attribute named 'pv' to the trades array that contains price*volume for every symbol and every time.
- `cumulate(..., sum(pv), sum(volume), ms)` computes the cumulative sum of the 'pv' and 'volume' attibutes running along the 'ms' coordimate axis.

Note that we're composing cumulate with an apply operator. SciDB's query
execution engine pipelines the data from the apply into the cumulate on an
as-needed basis. Finally, we divide the two running cumulative sums to get the
VWAP Remember, this quantity is computed for all the stocks!



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
that we know the symbol index for BAM is 615 from the last example. It takes
a short while to generate the query for this example because a few temporary
arrays that aggregate out the dummy dimension are generated (see the comments
in the script).

```
x=$(./last_value_join.sh "between(quotes, null,615,0, null,615,null)" "between(trades, null,615,0, null,615,null)")

# Count the result
iquery -aq "op_count($x)"

## {i} count
## {0} 4362


# This matches the count of the number of unique time elements for this
# instrument in the trades array:

iquery -aq "op_count(uniq(sort(cu(project(apply(between(trades,null,615,null,null,615,null), time, string(ms)),time)))))" 

## {i} count
## {0} 4362


# Show just part of the result
iquery -aq "$x" | head

## {symbol_index,ms} ask_price,bid_price,sequence_number,price,volume,sequence_number,condition,exchange
## {615,34185171} 41.6,37.8,300537,38.9,91,3309,'  TI','P'
## {615,34185172} 41.6,37.8,300537,39,100,3310,' FT ','T'
## {615,34185173} 41.6,37.8,300537,38.8,91,3312,'  TI','T'
## {615,34185950} 42,37.8,300938,38.8,9,3313,'  TI','T'
## {615,34200381} 40.1,37,305290,39.8,9761,3695,'O   ','N'
## {615,34200429} 40.1,39.2,305901,39.2,100,3742,' F  ','N'
## {615,34201201} 40.1,38.6,309302,38.9,100,3899,' F  ','Y'
## {615,34201215} 40.1,38.4,309342,38.8,100,3906,'Q   ','P'
## {615,34201216} 40.1,38.4,309342,38.8,100,3907,' F  ','P'
```

