#!/bin/bash

# last_value_join x y
#
# x,y: 2-d arrays with ms (time) and symbol_index coordinate axes such that the
#      count of y is not larger than x.
#
# Join the arrays x and y along time and symbol axes using every time
# coordinate in the array y. For each time coordinate in y, use the
# corresponding value in array x with the most recent time coordinate.  The
# output is a *query string* that, if run, produces an array with the same
# number of time points as y and the inner-join of x and y along the
# symbol_index axis.
#
# THIS SCRIPT ASSUMES that x is a 'quotes' array with schema
#
#    <ask_price:double null, bid_price:double null, sequence_number:int64 null>
#    [symbol_index=0:*,10,0, ms=0:86399999,86400000,0]
#
# If it does not, for example if x has extra dimensions, you should 'aggregate
# out' those extra dimensions to get the best bid and ask data over those
# dimensions. Redimension is often an effective way to do this. Comment the
# following lines out if your data don't indlude any extra dimesnions other
# than symbol_index and ms:
#
# Redimension the bigger quotes array (first argument)
x="redimension($1, <ask_price:double null, bid_price:double null, sequence_number:int64 null>[symbol_index=0:*,10,0, ms=0:86399999,86400000,0], min(ask_price) as ask_price, max(bid_price) as bid_price)"

# Redimension the smaller array
# get the smaller array's attribute schema:
smaller=$(echo $2 | sed -e "s/'/\\\\'/g")
attrs="<$(iquery -aq "show('filter($smaller,true)','afl')" | tail -n 1 | cut -d '<' -f 2 | cut -d '>' -f 1)>"
y="redimension($2, ${attrs}[symbol_index=0:*,10,0, ms=0:86399999,86400000,0], min(ask_price) as ask_price, max(bid_price) as bid_price)"

# (alternative)
#x="$1"   # bigger array
#y="$2"   # smaller array

# Note: if you want to keep the sizes corresponding to the best bid and ask
# prices too then a bit more work is required. But perhaps the easiest and
# fastest way to handle that case is to use a user-defined type to represent
# quotes, see https://github.com/paradigm4/quotes.

# We need this plugin for the last_value aggregate
iquery -aq "load_library('linear_algebra')" >/dev/null 2>&1

# time_points is a 1-d strip of all time points present in the y array
time_points="redimension($y, <count: uint64 null>[ms=0:86399999,86400000,0], count(*) as count)"

# x_symbols is a 1-d strip of all symbol indices present in the x array
x_symbols="aggregate($x, count(*) as count, symbol_index)"

# seek is a 2-d (ms x symbol_index) mask of desired data coordinates
seek="project(cross_join($x_symbols as x, $time_points as y), x.count)"

# merge the bigger data array with the desired data coordinate mask:
q="merge(project(apply($x, count, uint64(null)),count), $seek)"

# Apply the time coordinate values to a value called 'p'
q="apply($q, p, string(ms)+',')"

# Replace every time attribute with a comma-separated list of the time value
# and the last previously available time value
q1="variable_window($q, ms, 1, 0, sum(p) as p)"

# Filter on just the time values we're interested in from array y
q2="cross_join($q1 as x, $time_points as y, x.ms, y.ms)"

# Pick out the time values along a new coordinate axis 'i' (separate out the
# comma-separated list values)
q3="
apply(cross_join($q2,build(<b:bool>[i=0:1,2,0],false)),v,
  iif(i=0,int64(nth_tdv(p,0,',')), 
  iif(i=1 and char_count(p,',')>1,int64(nth_tdv(p,1,',')), null)))" 

# Redimension along the v attribute which includes the previous time point
# before every desired time point. The cast just relabels array axes.
q4="cast(
      redimension(apply($q3,
                    ask_price, double(null),
                    bid_price, double(null),
                    sequence_number, int64(null)),
<ask_price:double null, bid_price:double null, sequence_number: int64 null>
        [symbol_index=0:*,1,0,v=0:86399999,86400000,0]),
<ask_price:double null, bid_price:double null, sequence_number: int64 null>
        [symbol_index=0:*,1,0,ms=0:86399999,86400000,0])"


# Join the mask with the x array
fill="project(join(merge($x,$q4) as x, $q4 as y), x.ask_price, x.bid_price, x.sequence_number)"

# Impute the missing values with piecewise-constant interpolants over time
fill="cumulate($fill,
        last_value(ask_price) as ask_price,
        last_value(bid_price) as bid_price,
        last_value(sequence_number) as sequence_number, ms)"

# Finally, join the imputed x with y
answer="join($fill as x, $y as y)"

echo $answer
