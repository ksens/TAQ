#!/bin/bash

# prepare_for_last_value_join x y
#
# x,y: 2-d arrays with ms (time) and symbol_index coordinate axes such that the
#      count of y is not larger than x.
#
# Store the intermediate arrays with the following names
_x="quotes_redim"
_y="trades_redim"

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
# than symbol_index and ms. We cache these into temporary arrays.
#
# Redimension the bigger quotes array (first argument)
echo "### Redimensioning the bigger quotes array (first argument) "
iquery -naq "remove($_x)" >/dev/null 2>&1
iquery -naq "create TEMP array $_x <ask_price:double null, bid_price:double null>[symbol_index=0:*,10,0, ms=0:86399999,86400000,0]" >/dev/null 2>&1
iquery -naq "store(redimension($1, <ask_price:double null, bid_price:double null>[symbol_index=0:*,10,0, ms=0:86399999,86400000,0], min(ask_price) as ask_price, max(bid_price) as bid_price), $_x)" >/dev/null 2>&1
x=$_x
echo "... done"
echo 

# Redimension the smaller array
echo "### Redimensioning the smaller array"
# get the smaller array's attribute schema:
smaller=$(echo $2 | sed -e "s/'/\\\\'/g")
attrs="<$(iquery -aq "show('filter($smaller,true)','afl')" | tail -n 1 | cut -d '<' -f 2 | cut -d '>' -f 1)>"
iquery -naq "remove($_y)" >/dev/null 2>&1
iquery -naq "create TEMP array $_y ${attrs}[symbol_index=0:*,10,0, ms=0:86399999,86400000,0]" >/dev/null 2>&1
iquery -naq "store(redimension($2, ${attrs}[symbol_index=0:*,10,0, ms=0:86399999,86400000,0], FALSE), $_y)" >/dev/null 2>&1
y=$_y
echo "... done"
echo 

# (alternative if arrays don't have any extra dimensions)
#x="$1"   # bigger array
#y="$2"   # smaller array

# Note: if you want to keep the sizes corresponding to the best bid and ask
# prices too then a bit more work is required. But perhaps the easiest and
# fastest way to handle that case is to use a user-defined type to represent
# quotes, see https://github.com/paradigm4/quotes.

# We need this plugin for the as of join
iquery -aq "load_library('axial_aggregate')" >/dev/null 2>&1

echo "### Now run the AsOf join with the following command: "
echo "iquery -aq \"asof($x, $y)\""
