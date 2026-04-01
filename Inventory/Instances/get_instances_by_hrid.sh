#!/bin/bash
set -e
tenant=$(cat "`dirname $0`"/../../tenant)
okapi_url=$(cat "`dirname $0`"/../../okapi_url)
okapi_username=$(cat "`dirname $0`"/../../okapi_username)
okapi_password=$(cat "`dirname $0`"/../../okapi_password)
timestamp=$(date +%Y%m%d_%H%M%S)

# Token lifespan in seconds (default: 55 minutes)
TOKEN_LIFESPAN=${TOKEN_LIFESPAN:-3300}

# Check whether the argument for the input file has been specified
if [ "$#" -ne 1 ]; then
    echo "Please enter the file name for the input file with the UUID's."
    exit 1
fi
input_file="$1"

# Check whether the input file exists
if [ ! -f "${input_file}" ]; then
    echo "The input file '${input_file}' does not exist."
    exit 1
fi

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

# Output file
output_file="${input_file}_instances_${timestamp}.json"
jsonl_tmp=$(mktemp --tmpdir instances.XXXXXXXXXX.jsonl)

# Loop through each line in the input file and write the result into file
while IFS= read -r hrid || [ "${hrid}" ]; do
    ensure_valid_token
    echo "Processing HRID: ${hrid}"
    result=$(curl -s -X GET \
        -H "Accept: application/json" \
        -H "X-Okapi-Tenant: ${tenant}" \
        -H "x-okapi-token: ${okapi_token}" \
        "${okapi_url}/instance-storage/instances?query=hrid==${hrid}" | jq -c '.instances[0] // empty')
    [ -n "$result" ] && echo "${result}" >> "${jsonl_tmp}"
done < "${input_file}"

# Wrap all records into a JSON array
jq -cs '.' "${jsonl_tmp}" > "${output_file}"
rm "${jsonl_tmp}"

# HRID file
hrid_file="${output_file}_hrids.txt"

# Extract HRID's and write into file
echo "Extracting instance HRID's"
jq -r '.[].hrid' ${output_file} > ${hrid_file}

data_dir="data"
hrid_dir="hrid"
[ ! -d "$data_dir" ] && mkdir -p "$data_dir"
[ ! -d "$hrid_dir" ] && mkdir -p "$hrid_dir"
mv ${input_file} ${data_dir}
mv ${output_file} ${data_dir}
mv ${hrid_file} ${hrid_dir}

rm "$COOKIES"
echo "Script completed. See instance HRID's in file ${hrid_dir}/${hrid_file}"