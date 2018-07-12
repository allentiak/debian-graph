#!/usr/bin/sh

# $1: UDD dump file to generate
# $2: Docker container name (optional - requires sudo)

set -e
perl udd2dump.pl $1
mkdir ddb
perl dump2graphCSVs.pl $1
bash sort_uniq-graph_CSVs.sh
cd ddb
bash ../graphCSVs2Neo4j.sh $2
cd ..

echo "DONE: database files are in 'debian-neo4j'"
