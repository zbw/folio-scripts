#!/bin/bash

# This script accepts a JSON file containing agreement data,
# extracts specific fields, sorts the agreements by name,
# and outputs the result in TSV format.

# Exit on error
set -e

# Input file
INPUT="$1"

if [ -z "$INPUT" ]; then
    echo "Usage: $0 <inputfile.json>"
    exit 1
fi

# Check if file exists
if [ ! -f "$INPUT" ]; then
    echo "File not found: $INPUT"
    exit 1
fi

# Output filename: replace .json with .tsv
OUTPUT="${INPUT%.json}.tsv"

jq -r '
    ["ID", "Name", "Status"] as $headers |
    $headers,
    (sort_by(.name)[] | [.id, .name, .agreementStatus.value])
    | @tsv
' "$INPUT" > "$OUTPUT"

echo "Created: $OUTPUT"
