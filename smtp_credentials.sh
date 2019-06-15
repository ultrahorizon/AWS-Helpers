#!/usr/bin/env bash

# ----------------------------------------------------------------
# Converts an AWS Secret Access Key into SMTP Credentials for SES.
# ----------------------------------------------------------------

# These variables are required to calculate the SMTP password.
VERSION='\x02'
MESSAGE='SendRawEmail'

# Check to see if OpenSSL is installed. If not, exit with errors.
if ! [[ -x "$(command -v openssl)" ]]; then
  echo "Error: OpenSSL isn't installed." >&2
  exit 1
# If OpenSSL is installed, check to see that the environment variable has a
# length greater than 0. If not, exit with errors.
elif [[ -z "${AWS_SECRET_ACCESS_KEY}" ]]; then
  echo "Error: Couldn't find environment variable AWS_SECRET_ACCESS_KEY." >&2
  exit 1
fi

# If we made it this far, all of the required elements exist.
# Calculate the SMTP password.
(echo -en $VERSION; echo -n $MESSAGE \
 | openssl dgst -sha256 -hmac $AWS_SECRET_ACCESS_KEY -binary) \
 | openssl enc -base64
