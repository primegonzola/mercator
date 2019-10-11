#!/bin/bash
SERVICES_ID="$1"

PARTS=(${SERVICES_ID//// })
RESOURCE_GROUP=${PARTS[3]}
SERVICES_NAME=${PARTS[7]}

# get publishing profile
PUBLISHING_PROFILE_JSON=$(az webapp deployment list-publishing-profiles --resource-group ${RESOURCE_GROUP} --name ${SERVICES_NAME} --output json)
PUBLISHING_USERNAME=$(echo ${PUBLISHING_PROFILE_JSON} | jq -r '.[0] | .userName')
PUBLISHING_PASSWORD=$(echo ${PUBLISHING_PROFILE_JSON} | jq -r '.[0] | .userPWD')
AUTH_BASE64_TOKEN=$(printf ${PUBLISHING_USERNAME}:${PUBLISHING_PASSWORD} | iconv -t WINDOWS-1252 | base64 --wrap=0)
KUDU_EXEC_CMD_URI="https://"${SERVICES_NAME}".scm.azurewebsites.net/api/functions/admin/masterkey"

# get the credentials
GIT_NAME=${PUBLISHING_USERNAME}
GIT_PASSWORD=${PUBLISHING_PASSWORD}
# overide the deployment user
az webapp deployment user set --user-name ${GIT_NAME} --password ${GIT_PASSWORD}
# prepare 
pushd ..
# clean up first
rm -rf ${SERVICES_NAME}
# clone
git clone https://${GIT_NAME}:${GIT_PASSWORD}@${SERVICES_NAME}.scm.azurewebsites.net/${SERVICES_NAME}.git
# go into dir
cd ${SERVICES_NAME}
# config user name & email
git config user.name ${GIT_NAME}
git config user.email ${GIT_NAME}@${SERVICES_NAME}
# set simple push model
git config push.default simple
# copy sources into this repo  
# cp -a ../services/. .
cp -a ../services/deploy.cmd .
cp -a ../services/.deployment .
# mkdir mercator
# cp -a ../services/mercator/. ./mercator
# functions to install
MODULES="state status events "
# go over each function and prepare structure
for module in $MODULES; do
    mkdir -vp monitor-${module}
    mkdir -vp monitor-${module}/dist
    cp ../services/monitor/dist/index.js ./monitor-${module}/dist/index.js
    cp ../services/monitor/targets/${module}.package.json ./monitor-${module}/package.json
    cp ../services/monitor/targets/${module}.function.json ./monitor-${module}/function.json
done
# override git ignore
cat <<-EOF > ./.gitignore
npm-debug.log
package-lock.json
*/node_modules 
*/doc
*/test
**/*.sh
**/*.ts
**/*.config.js
EOF
# add changes to repo
git add .
# commit
git commit -m "New deployment"
# push it
git push https://${GIT_NAME}:${GIT_PASSWORD}@${SERVICES_NAME}.scm.azurewebsites.net/${SERVICES_NAME}.git
# clean up
cd ..
# clean up
rm -rf ${SERVICES_NAME}
# all done
popd

