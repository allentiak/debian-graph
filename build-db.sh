#!/usr/bin/sh

# $1: Docker container name (optional - requires sudo)

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

if [ $# = 1 ]; then
  echo "Importing data into local Neo4j container $1..."
  sudo docker exec $1 \
  neo4j-import --into ../debian-neo4j $cmdline
else
  echo "Importing data into local Neo4j server..."
  neo4j-import --into ../debian-neo4j $cmdline
fi
echo "Done"
