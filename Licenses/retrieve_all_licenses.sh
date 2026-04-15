#!/bin/bash
set -e

tenant=$(cat "`dirname $0`"/../tenant)
okapi_url=$(cat "`dirname $0`"/../okapi_url)
okapi_username=$(cat "`dirname $0`"/../okapi_username)
okapi_password=$(cat "`dirname $0`"/../okapi_password)
timestamp=$(date +%Y%m%d_%H%M%S)
endpoint="/licenses/licenses"

# Token lifespan in seconds (default: 55 minutes)
TOKEN_LIFESPAN=${TOKEN_LIFESPAN:-3300}

# Initialize variables
page=1
per_page=100
all_data="[]"
data_dir="data"
timestamp=$(date +%Y%m%d_%H%M%S)

# Files
temp_file="response_temp.json"
output_file="licenses_${timestamp}.json"

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

# Initial login
refresh_token

# Function to get the next page
fetch_data() {
    curl --silent --location --header "Cookie: folioAccessToken=$okapi_token" \
        "${okapi_url}${endpoint}?page=$1&perPage=$2" >"$temp_file"
}

# Loop for processing all data records
while :; do
    echo "Fetching data for page $page with $per_page records per page..."

    # API call
    ensure_valid_token
    fetch_data "$page" "$per_page"

    # Check whether the answer is valid
    if ! jq empty "$temp_file" 2>/dev/null; then
        echo "Invalid JSON response received, aborting!"
        break
    fi

    # Extract the array from the response
    data=$(jq '.' "$temp_file")

    # Check whether the array is empty
    if [ "$(echo "$data" | jq '. | length')" -eq 0 ]; then
        echo "No further data found."
        break
    fi

    # Insert data into the array, remove duplicates
    all_data=$(echo "$all_data" "$data" | jq -s 'add | unique_by(.id)')

    # Check if the number of records is less than per_page
    current_batch_size=$(echo "$data" | jq '. | length')
    if [ "$current_batch_size" -lt "$per_page" ]; then
        echo "End reached: The last page contains fewer than $per_page entries."
        break
    fi

    # Increment page
    page=$((page + 1))
done

# Write the entire array to the output file
all_data=$(echo "$all_data" | jq -c 'unique_by(.id)')
echo "$all_data" >"$output_file"
count=$(cat "$output_file" | jq -r '.[] | [.id] | @tsv' | wc -l)
unique_count=$(cat "$output_file" | jq -r '.[] | [.id] | @tsv' | sort | uniq | wc -l)
echo "$count records have been saved to $output_file ($unique_count are unique)."

# Cleanup
[ ! -d "$data_dir" ] && mkdir -p "$data_dir"
rm "$COOKIES"
mv "${temp_file}" "${data_dir}"
mv "${output_file}" "${data_dir}"
