#!/usr/bin/sh

set -e
perl pull-udd.pl
mkdir ddb
perl generate-graph.pl
bash sort-uniq.sh
cd ddb
bash ../build-db.sh
cd ..

echo "DONE: database files are in 'debian-neo4j'"
