#!/bin/bash
# via: https://stackoverflow.com/questions/20103258/accessing-azure-blob-storage-using-bash-curl

storage_account_name="$1"
storage_account_key="$2"
container_name="$3"
blob_name="$4"

blob_store_url="blob.core.windows.net"
authorization="SharedKey"

request_method="GET"
request_date=$(LC_TIME=en_US TZ=GMT date "+%a, %d %h %Y %H:%M:%S %Z")
storage_service_version="2011-08-18"

# HTTP Request headers

x_ms_date_h="x-ms-date:$request_date"
x_ms_version_h="x-ms-version:$storage_service_version"

# Build the signature string
canonicalized_headers="${x_ms_date_h}\n${x_ms_version_h}"
canonicalized_resource="/${storage_account_name}/${container_name}\ncomp:list\nrestype:container"
[[ "" != "$4" ]] && canonicalized_resource="/${storage_account_name}/${container_name}/$4"

string_to_sign="${request_method}\n\n\n\n\n\n\n\n\n\n\n\n${canonicalized_headers}\n${canonicalized_resource}"

# Decode the Base64 encoded access key, convert to Hex.
decoded_hex_key="$(echo -n $storage_account_key | base64 -d -w0 | xxd -p -c256)"

# Create the HMAC signature for the Authorization header
signature=$(printf "$string_to_sign" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:$decoded_hex_key" -binary | base64 -w0)

authorization_header="Authorization: $authorization $storage_account_name:$signature"

URL="https://${storage_account_name}.${blob_store_url}/${container_name}?restype=container&comp=list"

[[ "" != "$4" ]] && URL="https://${storage_account_name}.${blob_store_url}/${container_name}/$4"

curl -v --silent \
  -H "$x_ms_date_h" \
  -H "$x_ms_version_h" \
  -H "$authorization_header" \
  -o $5 \
  --create-dirs \
  "$URL"