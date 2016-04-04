#!/bin/bash

# Create an array dimensioned along three coordinate axes:
# dummy, just to separate conflicts--more efficient than using sequence_number
# symbol_index
# time (in ms)
# We use the same symbol index here that we built from the trade data.
iquery -naq "
store(
  redimension(
    index_lookup(quotes_flat as A,tkr, A.symbol, symbol_index),
    <ask_price:double null, ask_size:int64 null, bid_price:double null, bid_size:int64 null, sequence_number: int64 null, condition:string null, exchange: string null>
    [symbol_index=0:*,10,0, tm=0:86399999,86400000,0], false),
  quotes
)" || exit 1

# Clean up
iquery -aq "remove(quotes_flat)"
