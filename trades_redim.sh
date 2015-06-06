#!/bin/bash

# But it's still organized like the flat file. Let's redimension these data
# along time and symbol axes. First, let's make an indexed categorical variable
# for the various stock symbols in the data:
iquery -naq "load_library('cu')"
iquery -naq "
store(
  cast(
    uniq(sort(cu(project(trades_flat,symbol)))),
    <symbol:string> [symbol_index=0:*,1000000,0]),
  tkr)"

# Count the number of unique symbols:
iquery -aq "op_count(tkr)"
#{i} count
#{0} 7675

# Let's create an array dimensioned along three coordinate axes:
# dummy, just to separate conflicts--more efficient than using sequence_number
# symbol_index
# time (in ms)
# Note that we only have one day of data in this example. We could imagine
# adding another coordinate axis to track time up to the day, for example.

# To keep things simple, we ignore data collisions that could be separated by
# sequence number that would normally be handled using a SciDB _synthetic
# dimension_. Instead we just pick a random element among conflicts. I think
# that the best way to keep track of quotes is to instead use a user-defined
# quote type instead of separate attributes. Here we focus just on the last
# value join concept.  See https://github.com/paradigm4/quotes for more
# examples.

iquery -naq "
store(
  redimension(
    index_lookup(trades_flat as A,tkr, A.symbol, symbol_index),
    <price:double null, volume:int64 null, sequence_number: int64 null>
    [symbol_index=0:*,100,0,  ms=0:86399999,86400000,0]),
  trades
)"

# Clean up
iquery -aq "remove(trades_flat)"
