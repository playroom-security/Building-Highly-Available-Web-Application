#!/bin/bash
# Rendered user data for the web server

## Provide only the secret ARN to the instance. The app should fetch secrets via the SDK.
DB_SECRET_ARN="${db_secret_arn}"
cat >/etc/profile.d/app_env.sh <<-ENV
DB_SECRET_ARN="$DB_SECRET_ARN"
ENV

# Drop the static user_data shell that sets up app files (included afterwards)
${user_data_raw}
