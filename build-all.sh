#!/usr/bin/sh

# $1: UDD dump file

set -e
perl pull-udd.pl $1
mkdir ddb
perl generate-graph.pl $1
bash sort-uniq.sh
cd ddb
bash ../build-db.sh
cd ..

echo "DONE: database files are in 'debian-neo4j'"
