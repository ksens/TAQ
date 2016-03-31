#!/bin/bash
#
iquery -aq "load_library('accelerated_io_tools')"

# We obtain one day of NYSE TAQ nbbo quotes with (uncomment to download):
# wget ftp://ftp.nyxdata.com/Historical%20Data%20Samples/Daily%20TAQ/EQY_US_ALL_NBBO_20131218.zip
# The sample quotes cover the consolidated US exchanges for one day at
# millisecond resolution.

# We remove in advance the arrays we'll create below. The 2>/dev/null part
# supresses printing of errors (for example if the array doesn't exist).
iquery -naq "remove(quotes_flat)" 2>/dev/null
iquery -naq "remove(quotes)" 2>/dev/null

# The raw trade data in the TAQ file is presented in fixed-width ASCII fields.
# Parse each raw data trade line into distinct values, storing the result into
# a 1-d SciDB array named 'quotes_flat'. Note that we're only parsing out a few
# interesting fields from the raw data.  We could easily parse more.
rm -f /tmp/pipe
mkfifo /tmp/pipe
#zcat EQY_US_ALL_NBBO_20131218.zip |  tail -n +2  > /tmp/pipe &		# NOTE: The 'head -n 158850027' below is added to avoid an error in the file-ending; should not be necessary otherwise
zcat EQY_US_ALL_NBBO_20131218.zip | head -n 158850027 | tail -n +2  > /tmp/pipe &
iquery  -naq "
store(
  project(
    apply( aio_input( '/tmp/pipe', 'num_attributes=1'),
                ms, int64(substr(a0,0,2))*60*60000 +
                    int64(substr(a0,2,2))*60000 +
                    int64(substr(a0,4,2))*1000 +
                    int64(substr(a0,6,3)),
                exchange, substr(a0,9,1),
                symbol, trim(substr(a0,10,16)),
                bid_price, double(substr(a0,26,7)) +
                       double(substr(a0,33,4))/10000,
                bid_size, int64(substr(a0,37,7)),
                ask_price, double(substr(a0,44,7)) +
                       double(substr(a0,51,4))/10000,
                ask_size, int64(substr(a0,55,7)),
                condition, substr(a0,62,1),
                sequence_number, int64(substr(a0,69,16))
    ), ms, exchange, condition, symbol, bid_size, bid_price, ask_size, ask_price, sequence_number),
  quotes_flat)"
