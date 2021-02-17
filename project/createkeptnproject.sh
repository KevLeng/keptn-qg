#!/bin/bash
echo "Started: Create Keptn Project"

PROJECTNAME=${1}
SERVICENAME=${2}

if [[ -z "$PROJECTNAME" ]]; then
  echo "You have to specify a project name."
  echo "Usage: $0 <project-name> <service-name>"
  exit 1
fi

if [[ -z "$SERVICENAME" ]]; then
  echo "You have to specify a service name."
  echo "Usage: $0 <project-name> <service-name>"
  exit 1
fi

KEPTN_BRIDGE_URL=$(kubectl get secret dynatrace -n keptn -ojsonpath={.data.KEPTN_BRIDGE_URL} | base64 --decode)
DT_TENANT=$(kubectl get secret dynatrace -n keptn -ojsonpath={.data.DT_TENANT} | base64 --decode)
DT_API_TOKEN=$(kubectl get secret dynatrace -n keptn -ojsonpath={.data.DT_API_TOKEN} | base64 --decode)

STAGE="quality-gate"
DT_USERNAME="kevin.lend@dynatrace.com"
#STAGE_PROD=prod
#STAGE_STAGING=staging

echo "Replace fields..."
sed "s/REPLACE_DASHBOARD_OWNER/$DT_USERNAME/g;s/REPLACE_KEPTN_BRIDGE/$KEPTN_BRIDGE_URL/g" ./monaco/projects/default/dashboard/qualitygatedb.yaml.tmpl >> ./monaco/projects/default/dashboard/qualitygatedb.yaml
sed "s/REPLACE_SERVICE/$SERVICENAME/g" ./dynatrace/monaco.conf.yaml.tmpl >> ./dynatrace/monaco.conf.yaml

echo "Create Keptn Project: ${PROJECTNAME} based on shipyard.yaml"
keptn create project "${PROJECTNAME}" --shipyard=./shipyard.yaml

#echo "Adding JMeter files on project level"
#keptn add-resource --project="${PROJECTNAME}" --resource=${SERVICENAME}/jmeter/jmeter.conf.yaml --resourceUri=jmeter/jmeter.conf.yaml
#keptn add-resource --project="${PROJECTNAME}" --resource=${SERVICENAME}/jmeter/load.jmx --resourceUri=jmeter/load.jmx
#keptn add-resource --project="${PROJECTNAME}" --resource=${SERVICENAME}/jmeter/basiccheck.jmx --resourceUri=jmeter/basiccheck.jmx

echo "Adding dynatrace.conf.yaml on project level"
keptn add-resource --project="${PROJECTNAME}" --resource=./dynatrace/dynatrace.conf.yaml --resourceUri=dynatrace/dynatrace.conf.yaml
keptn add-resource --project="${PROJECTNAME}" --resource=./dynatrace/monaco.conf.yaml --resourceUri=dynatrace/monaco.conf.yaml

echo "Adding SLO files for ${STAGE}"
keptn add-resource --project="${PROJECTNAME}" --service=${SERVICENAME} --stage=${STAGE} --resource=./slo.yaml --resourceUri=slo.yaml


echo "Add monaco configuration for Quality Gate Dashboards for STAGING"
keptn add-resource --project="${PROJECTNAME}" --service="${SERVICENAME}" --stage="${STAGE}" --resource=./monaco/projects/default/dashboard/qualitygatedb.yaml --resourceUri=dynatrace/projects/${SERVICENAME}/dashboard/qualitygatedb.yaml
keptn add-resource --project="${PROJECTNAME}" --service="${SERVICENAME}" --stage="${STAGE}" --resource=./monaco/projects/default/dashboard/qualitygatedb.json --resourceUri=dynatrace/projects/${SERVICENAME}/dashboard/qualitygatedb.json
#keptn add-resource --project="${PROJECTNAME}" --service="${SERVICENAME}" --stage="${STAGE_STAGING}" --resource=simplenode/monaco/projects/simplenode/management-zone/keptn-mz.yaml --resourceUri=dynatrace/projects/${SERVICENAME}/management-zone/keptn-mz.yaml
#keptn add-resource --project="${PROJECTNAME}" --service="${SERVICENAME}" --stage="${STAGE_STAGING}" --resource=simplenode/monaco/projects/simplenode/management-zone/keptn-mz.json --resourceUri=dynatrace/projects/${SERVICENAME}/management-zone/keptn-mz.json


echo "Creating a Git Repository for this project"
#cd setup/gitea
#./create-upstream-git.sh ${PROJECTNAME}
#cd ../..

echo "==============================================================================="
echo "Just created your Keptn Project '$PROJECTNAME'"
echo "==============================================================================="
echo "VIEW IT in the Keptn's Bridge $KEPTN_BRIDGE_URL/project/$PROJECTNAME"
echo ""
echo "Finished: Create Keptn Project"