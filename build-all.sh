#!/usr/bin/sh

# $1: UDD dump file to generate
# $2: temporal directory for CSVs
# $3: output directory
# $4: Neo4j Docker container name (optional - requires sudo)

$udd_dumpfile = $1
$csv_temp_dir = $2
$output_dir = $3
$docker_container = $4

# TODO: add default parameter values

set -e
perl udd2dump.pl $udd_dumpfile
mkdir $csv_temp_dir
perl dump2graphCSVs.pl $udd_dumpfile $csv_temp_dir
bash sort_uniq-graph_CSVs.sh $csv_temp_dir
cd $csv_temp_dir
bash ../graphCSVs2Neo4j.sh $output_dir $docker_container
cd ..

echo "DONE: database files are in '$output_dir'"
