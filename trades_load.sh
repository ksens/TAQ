#!/bin/bash
#
# SciDB Examples using NYSE TAQ daily trades data
#
iquery -aq "load_library('accelerated_io_tools')"

# We obtain one day of NYSE TAQ trades with (uncomment to download):
# wget ftp://ftp.nyxdata.com/Historical%20Data%20Samples/Daily%20TAQ/EQY_US_ALL_TRADE_20131218.zip
# The sample trades cover the consolidated US exchanges for one day at
# millisecond resolution.

# We remove in advance the arrays we'll create below. The 2>/dev/null part
# supresses printing of errors (for example if the array doesn't exist).
iquery -naq "remove(trades_flat)" 2>/dev/null
iquery -naq "remove(tkr)" 2>/dev/null
iquery -naq "remove(trades)" 2>/dev/null
iquery -naq "remove(minute_bars)" 2>/dev/null

# The raw trade data in the TAQ file is presented in fixed-width ASCII fields.
# Let's parse each raw data trade line into distinct values, storing
# the result into a 1-d SciDB array named 'trades_flat'. Note that
# we're only parsing out a few interesting fields from the raw data.
# We could easily parse more.
rm -f /tmp/pipe
mkfifo /tmp/pipe
zcat EQY_US_ALL_TRADE_20131218.zip |  tail -n +2  > /tmp/pipe &
iquery  -naq "
store(
  project(
    apply( aio_input('/tmp/pipe', 'num_attributes=1'),
                ms, int64(substr(a0,0,2))*60*60000 +
                    int64(substr(a0,2,2))*60000 +
                    int64(substr(a0,4,2))*1000 +
                    int64(substr(a0,6,3)),
                exchange, substr(a0,9,1),
                symbol, trim(substr(a0,10,16)),
                condition, trim(substr(a0,26,4)),
                volume, int64(substr(a0,30,9)),
                price, double(substr(a0,39,7)) +
                       double(substr(a0,46,4))/10000,
                sequence_number, int64(substr(a0,53,16))
    ), ms, symbol, volume, price, exchange, condition, sequence_number),
  trades_flat)"
