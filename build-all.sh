#!/usr/bin/sh

# $1: UDD dump file
# $2: Docker container name (optional - requires sudo)

set -e
perl pull-udd.pl $1
mkdir ddb
perl generate-graph.pl $1
bash sort-uniq.sh
cd ddb
bash ../build-db.sh $2
cd ..

echo "DONE: database files are in 'debian-neo4j'"
