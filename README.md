# LetsEncrypt Openshift

This is an LetsEncrypt implementation to automatically generate certificates for Openshift routes and keep them up to date using LetsEncrypt.

## Prerequisites
The project you run this cronjob in needs to have a 'letsencrypt' service account with edit access. \
You can create this through the following commands : \
``$ PROJECT=<project>`` \
``$ oc create sa letsencrypt`` \
``$ oc adm policy add-role-to-user edit system:serviceaccount:$PROJECT:letsencrypt`` \

## Usage
you can use ``$ oc process`` to generate a personalised template with your own needed settings. \
Possible settings :

 - **NAME**  \
 *Default : le-cron* \
 Set the name of the cronjob and needed service, this is only needed when you want to run multiple in the same namespace.

 - **LEHOSTNAME** \
 *Default : auto* \
 Set the hostname you want to generate the certificates for. Set to 'auto' if you want to generate a certificate for every hostname in the project. Every hostname will always be checked if they are present and working on the platform.

 - **SCHEDULE** \
 *Default: 0 3 \* \* \** \
 Set the schedule for when to run the cronjob in the cronjob fashion.

- **ENVIRONMENT** \
*Default : staging* \
Select the 'staging' or 'production' environment of LetsEncrypt. The staging environment should be used when you are testing this tool, use the production environment when you are done testing and want a valid certificate.

- **FORCEHTTPS** \
*Default: false* \
In the 'false' setting non-HTTPS traffic will be allowed on the application. In the 'true' setting all non-HTTPS traffic will be redirected to HTTPS.

- **DEBUG** \
*default: false* \
When set to true will leave the cronjob container running after the job is done. You can stop the container by connecting to the container by podname and touching the file /tmp/stop ``$ oc rsh <podname> touch /tmp/stop``

### Examples
- All hostnames in project on production environment with forcing HTTPS \
``$ oc process -p ENVIRONMENT=production -p FORCEHTTPS=true -f https://raw.githubusercontent.com/npohosting/openshift-letsencrypt/master/cron.yaml | oc create -f -``
- Hostname app.example.com with schedule of daily at 5am \
``$ oc process -p LEHOSTNAME=app.example.com -p SCHEDULE="0 5 * * *" -f https://raw.githubusercontent.com/npohosting/openshift-letsencrypt/master/cron.yaml | oc create -f -``

## Remove cronjob
If you want to remove the cronjob you can do this by finding out the name of the cronjob \
``$ oc get cronjob`` \
And removing the cronjob and service by name. \
``$ oc process -p NAME=<name> -f https://raw.githubusercontent.com/npohosting/openshift-letsencrypt/master/cron.yaml | oc delete -f -``
