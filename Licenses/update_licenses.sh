#!/bin/bash

# Initialize variables
search="EOWYN"
replace="ENTERPRISE"
timestamp=$(date +%Y%m%d_%H%M%S)

# OKAPI information
okapi_token=$(cat "$(dirname $0)"/../okapi_token)
okapi_url=$(cat "$(dirname $0)"/../okapi_url)
endpoint="licenses/licenses"

# Files
# Files
data_file=$1
if [[ -z "$data_file" ]]; then
    echo "Error: No input file provided. Usage: $0 <data_file>"
    exit 1
fi
data_file_replaced="${data_file}_replaced.json"
data_file_replaced_matched="${data_file_replaced}_matched.json"
uuid_file="data/uuids.txt"
data_dir="data"
records_dir="data/records"

# Step 1: Search and replace values in .docs[].location field
jq --arg search "$search" --arg replace "$replace" \
    'map(.docs |= map(if .location != null then .location |= gsub($search; $replace) else . end))' \
    "$data_file" >"$data_file_replaced"
echo "Step 1: Replaced file created: $data_file_replaced"

# Step 2: Filter all records that have been touched in step 1
jq --arg replace "$replace" \
    'map(select(.docs[] | any(.location?; . != null and test($replace; "i"))))' \
    "$data_file_replaced" >"$data_file_replaced_matched"
echo "Step 2: Filtered matched records: $data_file_replaced_matched"

# Step 3: Extract UUIDs
#mkdir -p "$(dirname "$uuid_file")" # Ensure the directory exists
#jq 'map(.id)' "$data_file_replaced_matched" >"$uuid_file"
#echo "Step 3: UUIDs extracted to: $uuid_file"

# Step 4: Split into separate files, one per record
jq -c '.[]' "$data_file_replaced_matched" | nl -nln | while read -r index json; do
    mkdir -p "${records_dir}"
    echo "$json" >"${records_dir}/record_${index}.json"
done
echo "Step 4: Split files created for each matched record."

# Step 5: PUT to API
for json_file in "${records_dir}"/*.json; do
    uuid=$(jq -r '.id' "$json_file")
    if [[ -z "$uuid" ]]; then
        echo "Fehler: Keine UUID in der Datei $json_file gefunden."
        continue
    fi
    echo "Verarbeite Datei $json_file mit UUID $uuid"

    echo "Endpoint: ${okapi_url}/${endpoint}"
    echo "Request: ${okapi_url}/${endpoint}/${uuid}"

    curl -s --location --request PUT "${okapi_url}/${endpoint}/${uuid}" \
        --header "Cookie: folioAccessToken=${okapi_token}" \
        --header "Content-Type: application/json" \
        --data @"$json_file"

    echo "PUT-Request für UUID $uuid gesendet."

done