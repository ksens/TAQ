#!/bin/bash

# Let's turn to another common kind of operation, computing volume-weighted
# average price (VWAP). We'll compute it for every instrument across their raw
# trade data in the array tades.

iquery -naq "
store(
  apply(
    cumulate(
      apply(trades, pv, price*volume),
      sum(pv) as numerator,
      sum(volume) as denominator, ms),
    vwap, numerator/denominator),
  VWAP)"

# This query takes a little longer, but not too long to run. It computes
# and stores vwap on the millisecond data for all instruments. Here is a brief
# overview of each step:

# apply(trades, pv, price*volume) adds a new attribute named 'pv' to the trades
# array that contains price*volume for every symbol and every time.
# cumulate(..., sum(pv), sum(volume), ms) computes the cumulative sum of the
# 'pv' and 'volume' attibutes running along the 'ms' coordimate axis.  Note
# that we're composing cumulate with an apply operator. SciDB's query execution
# engine pipelines the data from the apply into the cumulate on an as-needed
# basis. Finally, we divide the two running cumulative sums to get the VWAP.
# Remember, this quantity is computed for all the stocks.
