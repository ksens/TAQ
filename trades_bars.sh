#!/bin/bash

# The trade data are now organized by symbol and time in a sparse array.
# Let's create one-minute open/high/low/close bars from these data. We need
# some extra aggregates from the openclose plugin, so let's load that:
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

# This query runs in seconds or less, even on modest desktop machines. It
# produces one-minute bars for *all* 7412 stocks at once.

# Let's deconstruct the query:

# regrid(trades, 1000, 1, 60000, ...) applies the open/high/low/close summary
# statistics over regular rectilinear regions along the coordinate axes.  The
# rectangles have dimension 1000 dummy dimension (sequence_numbers) by 1 symbol
# by 60000 milliseconds.  That means we compute the open/high/low/close price
# over all sequence numbers for each symbol per one minute.

# slice(..., dummy ,0) removes the dummy (sequence number_ coordinate axis from
# the result. It's no longer needed because all trades for each symbol and
# minute have been accounted for in the regrid aggregate. So slice simply
# removes this no longer used axis.

# We're left with an array named 'minute_bars' that has two dimensions:
# symbol_index and 60000 ms (that is, minutes). The array is still sparse
# beause some thinly traded instruments may not have had any trades in some of
# the minute intervals.


# Let's pull out one of these minute bar time series for a particuar stock,
# CVS.  We can consult the symbols array to find it's index directly.

iquery -aq "filter(apply(trade_symbols,x,regex(symbol, 'CVS')), x=true)"
# {i} symbol,x
# {1612} 'CVS',true

# So this says that symbol index 1612 corresponds to CVS.

# We can  use SciDB's cross_join to avoid an explicit index lookup. We do need
# to use a repart to bring the symbols array schema into a conformable chunking
# scheme with the minute_bars array. Only the first 10 minutes of bars are
# shown below:
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


# Note! That  570 minutes = 9:30 AM.
