#!/usr/bin/sh

# $1: output directory
# $2: Neo4j Docker container name (optional - requires sudo)

output_dir = $1
container_name = $2

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
  echo "Importing data into local Neo4j container $container_name..."
  sudo docker exec $container_name \
  neo4j-import --into ../debian-neo4j $cmdline
else
  echo "Importing data into local Neo4j server..."
  neo4j-import --into ../$output_dir $cmdline
fi
echo "Done"
