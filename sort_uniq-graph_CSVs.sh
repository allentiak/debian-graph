#!/usr/bin/sh
#
# $1: CSVs' directory

csv_dir = $1;

# unify lines of files to guarantee no multiple connections
for i in $csv_dir/*.csv ; do
  head -1 $i > bla
  tail -n +2 $i | sort | uniq >> bla
  mv bla $i
done
