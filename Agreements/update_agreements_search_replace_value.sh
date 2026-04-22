#!/bin/bash
set -e
tenant=$(cat "`dirname $0`"/../tenant)
okapi_url=$(cat "`dirname $0`"/../okapi_url)
okapi_username=$(cat "`dirname $0`"/../okapi_username)
okapi_password=$(cat "`dirname $0`"/../okapi_password)
timestamp=$(date +%Y%m%d_%H%M%S)
endpoint="erm/sas"

# Token lifespan in seconds (default: 55 minutes)
TOKEN_LIFESPAN=${TOKEN_LIFESPAN:-3300}

# Initialize search/replace variables
search="http://zbwintern/jira"
replace="https://zbw.atlassian.net"

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

# Login and store cookies, set token timestamp
COOKIES=$(mktemp --tmpdir cookies.XXXXXXXXXX)
token_timestamp=0

refresh_token() {
    echo "Fetching new token..."
    # Clear and recreate cookie file
    > "$COOKIES"
    LOGIN=$(jq -n -c --arg username "$okapi_username" --arg password "$okapi_password" \
        '{"username": $username, "password": $password}')
    curl -sS -D - -j -c "$COOKIES" \
        -H "X-Okapi-Tenant: ${tenant}" \
        -H "Content-type: application/json" \
        -d "$LOGIN" \
        "${okapi_url}/authn/login-with-expiry"

    okapi_token=$(grep -oP '(?<=\tfolioAccessToken\t)\S+' "$COOKIES")
    if [ -z "$okapi_token" ]; then
        echo "Failed to extract folioAccessToken from cookies."
        rm "$COOKIES"
        exit 1
    fi
    token_timestamp=$(date +%s)
    echo "Token refreshed at $(date -d @${token_timestamp})"
}

ensure_valid_token() {
    local now
    now=$(date +%s)
    if [ $(( now - token_timestamp )) -ge "$TOKEN_LIFESPAN" ]; then
        refresh_token
    fi
}

# Step 1: Search and replace values in .supplementaryDocs[].location field
jq --arg search "$search" --arg replace "$replace" \
    'map(.supplementaryDocs |= map(if .location != null then .location |= gsub($search; $replace) else . end))' \
    "$data_file" >"$data_file_replaced"
echo "Step 1: Replaced file created: $data_file_replaced"

# Step 2: Filter all records that have been touched in step 1
jq --arg replace "$replace" \
    'map(select(.supplementaryDocs[] | any(.location?; . != null and test($replace; "i"))))' \
    "$data_file_replaced" >"$data_file_replaced_matched"
echo "Step 2: Filtered matched records: $data_file_replaced_matched"

# Step 3: Split into separate files, one per record
jq -c '.[]' "$data_file_replaced_matched" | nl -nln | while read -r index json; do
    mkdir -p "${records_dir}"
    echo "$json" >"${records_dir}/record_${index}.json"
done
echo "Step 3: Split files created for each matched record."

read -p "Are you sure you want to UPDATE these agreements? Then type \"y\" to proceed: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Initial login
    refresh_token

    # Step 4: PUT to API
    for json_file in "${records_dir}"/*.json; do
        ensure_valid_token
        uuid=$(jq -r '.id' "$json_file")
        if [[ -z "$uuid" ]]; then
            echo "Error: No UUID found in the file $json_file."
            continue
        fi
        echo "Processing file $json_file with UUID $uuid"

        echo "Endpoint: ${okapi_url}/${endpoint}"
        echo "Request: ${okapi_url}/${endpoint}/${uuid}"

        curl -s --location --request PUT "${okapi_url}/${endpoint}/${uuid}" \
            --header "Cookie: folioAccessToken=${okapi_token}" \
            --header "Content-Type: application/json" \
            --data @"$json_file"

        echo "PUT request sent for UUID $uuid."

    done

    read -p "Do you want to delete the temporary record files? Then type \"y\" to proceed: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm "${records_dir}"/*.json
        echo "Local records deleted."
    else
        echo "Local records not deleted."

    fi

else
    echo "Operation aborted."

fi
