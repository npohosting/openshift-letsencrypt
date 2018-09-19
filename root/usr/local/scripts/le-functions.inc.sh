#!/usr/bin/env bash

getExistingCerts(){

  hostname=$1

  defaultRoute=$(oc get -o json route | jq ".items[] | select(.spec.host==\"$hostname\") | select(.spec.path == null ) | .metadata.name" | sed 's/"//g')

  certDir=/tmp/dehydrated/certs/$hostname
  mkdir -p $certDir

  certExists=$(oc get route --export -o json $defaultRoute | jq '.spec.tls.key!=null')
  echo "-- cert : $certExists"
  if [ "$certExists" == "true" ];
  then
    printf "$(oc get route --export -o json $defaultRoute | jq '.spec.tls.key')" | sed 's/"//g' > $certDir/privkey-import.pem
    printf "$(oc get route --export -o json $defaultRoute | jq '.spec.tls.certificate')" | sed 's/"//g' > $certDir/cert-import.pem
    printf "$(oc get route --export -o json $defaultRoute | jq '.spec.tls.caCertificate')" | sed 's/"//g' > $certDir/chain-import.pem

    ln -sfn $certDir/privkey-import.pem $certDir/privkey.pem
    ln -sfn $certDir/cert-import.pem $certDir/cert.pem
    ln -sfn $certDir/chain-import.pem $certDir/chain.pem
  fi

}

placeCerts(){

  hostname=$1
  httpPolicy=$2

  CERT_KEY=$(cat /tmp/dehydrated/certs/$hostname/privkey.pem)
  CERT_CERT=$(cat /tmp/dehydrated/certs/$hostname/cert.pem)
  CERT_CACERT=$(cat /tmp/dehydrated/certs/$hostname/chain.pem)

  routes=$(oc get -o json route | jq ".items[] | select(.spec.host==\"$hostname\") | .metadata.name" | sed 's/"//g')

  for route in $routes;
  do
    # Check if there is already an certificate active on the route
    certExists=$(oc get route --export -o json $route | jq '.spec.tls.key!=null')

    if [ "$certExists" == "true" ];
    then
      # Check if old certificate and new certificate aren't the same
      SUM_ORI=$(openssl dgst -sha256 /tmp/dehydrated/certs/$hostname/cert-import.pem | awk '{print $2}')
      SUM_CERT=$(openssl dgst -sha256 /tmp/dehydrated/certs/$hostname/cert.pem | awk '{print $2}')

      if [ "$SUM_ORI" != "$SUM_CERT" ];
      then
        # New certificate gained, place new certificate
        oc get route --export -o json $route | jq ".spec += { tls: { termination: \"edge\", insecureEdgeTerminationPolicy: \"$httpPolicy\", key: \"$CERT_KEY\", certificate: \"$CERT_CERT\", caCertificate: \"$CERT_CACERT\" } }" | oc replace -f -
      fi
    else
      # No certificate exists, so place new one
      oc get route --export -o json $route | jq ".spec += { tls: { termination: \"edge\", insecureEdgeTerminationPolicy: \"$httpPolicy\", key: \"$CERT_KEY\", certificate: \"$CERT_CERT\", caCertificate: \"$CERT_CACERT\" } }" | oc replace -f -
    fi
  done

}

getCerts(){

  hostname=$1

  # Expose well-known route
  oc expose service ${NAME} \
                    --name=le-cron-${hostname} \
                    --hostname="${hostname}" \
                    --path=/.well-known/acme-challenge

  # Get certificates
  dehydrated --cron --accept-terms -d $hostname

  # Cleanup well-known route
  oc delete route le-cron-${hostname}

}

ocLogin(){
  # get token
  TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
  # login oc
  oc login --certificate-authority='/var/run/secrets/kubernetes.io/serviceaccount/ca.crt' --token="$TOKEN" https://openshift.default.svc.cluster.local/
}

getHostnames(){

  hosts=$1
  if [ "$hosts" == "auto" ];
  then
    hosts=$(oc get -o json route | jq ".items[] | .spec.host" | sort | uniq | sed 's/"//g')
  fi

  hostList=""

  for hostname in $hosts;
  do

    checkHash=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

    echo $checkHash > /usr/share/nginx/html/.well-known/acme-challenge/host-verify

    # Expose well-known route
    oc expose service ${NAME} \
                      --name=hostnames-verify-${hostname} \
                      --hostname="${hostname}" \
                      --path=/.well-known/acme-challenge

    getHash=$(/usr/bin/curl -s http://$hostname/.well-known/acme-challenge/host-verify)

    if [ "$checkHash" == "$getHash" ];
    then
      # hashes the same, save hostname
      hostList="$hostList $hostname"
      #echo "$hostname is on system"
    fi

    # Cleanup well-known route
    oc delete route hostnames-verify-${hostname}
  done

  export hostList="$hostList"
}
