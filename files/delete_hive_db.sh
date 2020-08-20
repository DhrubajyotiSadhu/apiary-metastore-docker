#!/bin/bash

set -x

if [ "$#" -ne 1 ]; then
    echo "Usage: delete_hive_db.sh <databaseName>"
    exit 1
fi

[[ -z "$MYSQL_DB_USERNAME" ]] && export MYSQL_DB_USERNAME=$(aws secretsmanager get-secret-value --secret-id ${MYSQL_SECRET_ARN}|jq .SecretString -r|jq .username -r)
[[ -z "$MYSQL_DB_PASSWORD" ]] && export MYSQL_DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id ${MYSQL_SECRET_ARN}|jq .SecretString -r|jq .password -r)

MYSQL_OPTIONS="-h$MYSQL_DB_HOST -u$MYSQL_DB_USERNAME -p$MYSQL_DB_PASSWORD $MYSQL_DB_NAME -N"

echo "DELETE FROM DBS WHERE name='$1';"|mysql $MYSQL_OPTIONS
if [ $? -ne 0 ] ; then
    echo "Error deleting Hive database $1"
fi