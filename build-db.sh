#!/usr/bin/sh

cmdline=
for x in node-*.csv ; do
  bn=`basename $x .csv`
  n=`echo $bn | sed -e 's/^node-//'`
  cmdline="$cmdline --nodes:$n $x"
done
for x in edge-*.csv ; do
  bn=`basename $x .csv`
  n=`echo $bn | sed -e 's/^edge-//'`
  cmdline="$cmdline --relationships:$n $x"
done

neo4j-import --into ../debian-neo4j $cmdline
