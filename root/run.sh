#!/bin/sh

source /usr/local/scripts/le-functions.inc.sh

# Defaults
le_api="https://acme-staging-v02.api.letsencrypt.org/directory"
http_policy='Allow'

LEENV=${LEENV:-staging}
FORCEHTTPS=${FORCEHTTPS:-false}
LEHOSTNAME=${LEHOSTNAME:-auto}


# Set LetsEncrypt environment
case $LEENV in
  production)
    le_api="https://acme-v02.api.letsencrypt.org/directory"
    ;;
esac

case $FORCEHTTPS in
  true)
    http_policy='Redirect'
    ;;
esac

# Create dehydrated config
sed "s#REPLACED_BY_SCRIPT#$le_api#g" /usr/local/etc/dehydrated/config.default > /usr/local/etc/dehydrated/config

# Start Nginx
nginx

# Login to Openshift
ocLogin

# Get list of hostnames
getHostnames "$LEHOSTNAME"

# Do your thing
for vhost in $hostList;
do
  # Get existing certificates from OC (if present)
  getExistingCerts $vhost

  # expose well-known and run Dehydrated
  getCerts $vhost

  # Place new certificates when needed
  placeCerts $vhost $http_policy
done

# TMP! keep pod alive for debugging
if [ "$DEBUG" == "true" ];
then

  echo "# LEHOSTNAME : $LEHOSTNAME"
  echo "# LEENV : $LEENV"
  echo "# FORCEHTTPS : $FORCEHTTPS"
  echo "# le_api : $le_api"
  echo "# http_policy : $http_policy"

  while [ ! -f /tmp/stop ];
  do
    echo "-- Keepalive notice";
    sleep 60;
  done

fi

echo "Jobs done";
