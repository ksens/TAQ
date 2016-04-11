#!/bin/bash

iquery -naq "remove(quotes2)" 2>/dev/null
iquery -naq "remove(trades2)" 2>/dev/null

echo "Redimensioning the quotes array"
#iquery -naq "store(aggregate(quotes, min(sequence_number), symbol_index, tm), quotes_min_seq2)"
iquery -naq "store(redimension(apply(apply(cross_join(quotes as A, aggregate(quotes, min(sequence_number), symbol_index, tm) as B, A.symbol_index, B.symbol_index, A.tm, B.tm), subi, sequence_number - sequence_number_min), tm_us, tm*1000 + subi), <tm:int64, ask_price:double,ask_size:int64,bid_price:double,bid_size:int64,sequence_number:int64,condition:string,exchange:string> [symbol_index=0:*,10,0, tm_us=0:*,86400000000,0]), quotes2)"

echo "Redimensioning the trades array"
iquery -naq "store(redimension(apply(apply(cross_join(trades as A, aggregate(trades, min(sequence_number), tm) as B, A.tm, B.tm), subi, sequence_number - sequence_number_min), tm_us, tm*1000 + 500 + subi), <tm:int64, price:double,volume:int64,sequence_number:int64,condition:string,exchange:string> [symbol_index=0:*,10,0, tm_us=0:*,86400000000,0]), trades2)"

time iquery -naq "store(asof(quotes2 as A, trades2, A.tm_us, 5, false), asof1)"
