#!/bin/bash
set -e
tenant=$(cat "`dirname $0`"/../tenant)
okapi_url=$(cat "`dirname $0`"/../okapi_url)
okapi_username=$(cat "`dirname $0`"/../okapi_username)
okapi_password=$(cat "`dirname $0`"/../okapi_password)
timestamp=$(date +%Y%m%d_%H%M%S)
endpoint="/erm/entitlements"

# Token lifespan in seconds (default: 55 minutes)
TOKEN_LIFESPAN=${TOKEN_LIFESPAN:-3300}

# Initialize variables
data_dir="data"
timestamp=$(date +%Y%m%d_%H%M%S)

# Files
temp_file="response_temp.json"
output_file="agreement_lines_${timestamp}.json"

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

# Check whether the argument for the input file has been specified
if [ "$#" -ne 1 ]; then
    echo "Please enter the file name for the input file with the UUID's."
    exit 1
fi

input_file="$1"
sync_state="SYNCHRONIZING"

# Check whether the input file exists
if [ ! -f "${input_file}" ]; then
    echo "The input file '${input_file}' does not exist."
    exit 1
fi

# Output file
output_file="${input_file}_updated_${timestamp}.json"
jsonl_tmp=$(mktemp --tmpdir instances.XXXXXXXXXX.jsonl)

# Extract package IDs from the input file
# Only processes entries if resource.class == "org.olf.kb.Pkg"
mapfile -t package_ids < <(jq -r '.[] | select(.resource.class == "org.olf.kb.Pkg") | .resource.id' "${input_file}" | tr -d '\r')

if [ ${#package_ids[@]} -eq 0 ]; then
    echo "No package IDs found in '${input_file}'. Exiting."
    rm "$COOKIES" "$jsonl_tmp"
    exit 0
fi

echo "Found ${#package_ids[@]} package(s) to update."
read -p "Are you sure you want to trigger sync for these packages? Then type \"y\" to proceed: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Initial login
    refresh_token

    # Set log directory
    updated_record_dir="log_updated_records"
    [ ! -d "$updated_record_dir" ] && mkdir -p "$updated_record_dir"

    # Log file with package IDs
    log_file="${updated_record_dir}/sync_${timestamp}.log"
    printf '%s\n' "${package_ids[@]}" > "${log_file}"
    echo "Package IDs written to ${log_file}"

    # Build payload with all package IDs at once
    payload=$(jq -n -c \
        '{"packageIds": $ARGS.positional, "syncState": "SYNCHRONIZING"}' \
        --args "${package_ids[@]}")
    # echo "Payload: ${payload}"  # For debugging
    echo "Sending sync request for ${#package_ids[@]} package(s)..."

    http_status=$(curl -s -o "${temp_file}" -w "%{http_code}" \
        -X POST \
        -d "${payload}" \
        -H "Content-type: application/json" \
        -H "x-okapi-tenant: ${tenant}" \
        -H "x-okapi-token: ${okapi_token}" \
        "${okapi_url}/erm/packages/controlSync")

    response_body=$(cat "${temp_file}")

    if [[ "$http_status" =~ ^2 ]]; then
        echo "Success (HTTP status code ${http_status})"
        if echo "$response_body" | jq -e . > /dev/null 2>&1; then
            cp "${temp_file}" "${output_file}"
        else
            echo "{\"status\": \"updated\", \"http_status\": ${http_status}, \"packageIds\": $(jq -n -c '$ARGS.positional' --args "${package_ids[@]}")}" > "${output_file}"
        fi
    else
        echo "ERROR (HTTP status code ${http_status}): ${response_body}"
        echo "{\"status\": \"error\", \"http_status\": ${http_status}, \"response\": $(echo "$response_body" | jq -R -s '.')}" > "${output_file}"
    fi

    rm -f "${jsonl_tmp}" "${temp_file}"

    # Move output file to log directory
    mv "${output_file}" "${updated_record_dir}"
    echo ""
    echo "Script completed. See logs in ${updated_record_dir}."

    rm "$COOKIES"
else
    echo "Operation aborted."
    rm "$COOKIES" "$jsonl_tmp"
fi