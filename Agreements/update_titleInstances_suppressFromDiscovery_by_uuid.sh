#!/bin/bash
set -e
tenant=$(cat "`dirname $0`"/../tenant)
okapi_url=$(cat "`dirname $0`"/../okapi_url)
okapi_username=$(cat "`dirname $0`"/../okapi_username)
okapi_password=$(cat "`dirname $0`"/../okapi_password)
timestamp=$(date +%Y%m%d_%H%M%S)
endpoint="/erm/sas"

# Token lifespan in seconds (default: 55 minutes)
TOKEN_LIFESPAN=${TOKEN_LIFESPAN:-3300}

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
suppress_switch="false"

# Check whether the input file exists
if [ ! -f "${input_file}" ]; then
    echo "The input file '${input_file}' does not exist."
    exit 1
fi

# Output file
output_file="${input_file}_updated_${timestamp}.json"
jsonl_tmp=$(mktemp --tmpdir instances.XXXXXXXXXX.jsonl)

read -p "Are you sure you want to UPDATE these titleInstances? Then type \"y\" to proceed: " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then

    # Initial login
    refresh_token

    # Loop through each line in the input file and write the result into file
    while IFS= read -r uuid || [ "${uuid}" ]; do
        ensure_valid_token
        uuid_cleaned=$(echo "${uuid}" | tr -d '\r' | xargs)
        echo "Processing UUID: ${uuid}"
        result=$(curl -s -w '\n' -X PUT -d "{ \"suppressFromDiscovery\": ${suppress_switch} }" -H "Content-type: application/json" -H "x-okapi-tenant: ${tenant}" -H "x-okapi-token: ${okapi_token}" "${okapi_url}/erm/titles/${uuid_cleaned}")
        #echo "$result" >> "${output_file}"
        echo "$result" >> "${jsonl_tmp}"
    done < "$input_file"

    # Wrap all records into a JSON array
    jq -cs '.' "${jsonl_tmp}" > "${output_file}"
    rm "${jsonl_tmp}"

    updatedRecordDir="log_updated_records"

    [ ! -d "$updatedRecordDir" ] && mkdir -p "$updatedRecordDir"

    mv ${output_file} ${updatedRecordDir}

    echo "Script completed. See logs in ${updatedRecordDir}."
    
    rm "$COOKIES"

else
    echo "Operation aborted."

fi



