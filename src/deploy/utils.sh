function replace_versions() {
	sed -e "s|<appInsightsApiVersion>|${APP_INSIGHTS_API_VERSION}|" \
		-e "s|<applicationGatewaysApiVersion>|${APPLICATION_GATEWAYS_API_VERSION}|" \
		-e "s|<autoScaleSettingsApiVersion>|${AUTO_SCALE_SETTINGS_API_VERSION}|" \
		-e "s|<deploymentsApiVersion>|${DEPLOYMENTS_API_VERSION}|" \
		-e "s|<imagesApiVersion>|${IMAGES_API_VERSION}|" \
		-e "s|<loadBalancersApiVersion>|${LOAD_BALACERS_API_VERSION}|" \
		-e "s|<networkInterfacesApiVersion>|${NETWORK_INTERFACES_API_VERSION}|" \
		-e "s|<networkSecurityGroupsApiVersion>|${NETWORK_SECURITY_GROUPS_API_VERSION}|" \
		-e "s|<publicIPAddressesApiVersion>|${PUBLIC_IP_ADDRESSES_API_VERSION}|" \
		-e "s|<serverFarmsApiVersion>|${SERVER_FARMS_API_VERSION}|" \
		-e "s|<sitesApiVersion>|${SITES_API_VERSION}|" \
		-e "s|<sitesExtensionsApiVersion>|${SITES_EXTENSIONS_API_VERSION}|" \
		-e "s|<storageAccountsApiVersion>|${STORAGE_ACCOUNTS_API_VERSION}|" \
		-e "s|<virtualMachinesExtensionsApiVersion>|${VIRTUAL_MACHINES_API_VERSIONS}|" \
		-e "s|<virtualMachinesApiVersion>|${VIRTUAL_MACHINES_EXTENSIONS_API_VERSIONS}|" \
		-e "s|<virtualMachineScaleSetsApiVersion>|${VIRTUAL_MACHINE_SCALE_SETS_API_VERSIONS}|" \
		-e "s|<virtualMachineScaleSetsExtensionsApiVersion>|${VIRTUAL_MACHINE_SCALE_SETS_EXTENSIONS_API_VERSIONS}|" \
		-e "s|<virtualNetworksApiVersion>|${VIRTUAL_NETWORKS_API_VERSIONS}|" \
		-e "s|<workspacesApiVersion>|${WORKSPACES_API_VERSIONS}|" \
		-e "s|<workspacesDataSourcesApiVersion>|${WORKSPACES_DATA_SOURCES_API_VERSIONS}|" \
		-e "s|<workspacesSavedSearchesApiVersion>|${WORKSPACES_SAVED_SEARCHES_API_VERSIONS}|" \
		-e "s|<workspacesSavedSearchesSchedulesApiVersion>|${WORKSPACES_SAVED_SEARCHES_SCHEDULES_API_VERSIONS}|" \
		-e "s|<workspacesSavedSearchesSchedulesActionsApiVersion>|${WORKSPACES_SAVED_SEARCHES_SCHEDULES_ACTIONS_API_VERSIONS}|" \
		-e "s|<workspacesViewsApiVersion>|${WORKSPACES_VIEWS_API_VERSIONS}|" \
		-e "s|<roleAssignments>|${ROLE_ASSIGNMENTS_API_VERSIONS}|" \
		-e "s|<identities>|${IDENTITIES_API_VERSIONS}|" \
		-e "s|<keyVaults>|${KEY_VAULTS_API_VERSIONS}|" \
		-e "s|<eventGrids>|${EVENT_GRID_API_VERSIONS}|" \
		-e "s|<automationAccounts>|${AUTOMATION_ACCOUNTS_API_VERSIONS}|" \
		-e "s|<disks>|${DISKS_API_VERSIONS}|" \
		$1 >$2
}

function require_tool() {
	which $1 &>/dev/null
	if [ $? -ne 0 ]; then
		echo >&2 "Error: Unable to find required '$1' helper tool."
		return 1
	else
		return 0
	fi
}

# prepare
plus_one_year="-d +1year"
[[ $(uname) == "Darwin" ]] && plus_one_year="-v+1y"

function pusha() {
	pushd "$1" &>/dev/null
}

function popa() {
	popd &>/dev/null
}

function color() {
	case $1 in
	default) echo -e -n "\e[39m$2\e[0m" ;;
	black) echo -e -n "\e[30m$2\e[0m" ;;
	red) echo -e -n "\e[31m$2\e[0m" ;;
	green) echo -e -n "\e[32m$2\e[0m" ;;
	yellow) echo -e -n "\e[33m$2\e[0m" ;;
	blue) echo -e -n "\e[34m$2\e[0m" ;;
	magenta) echo -e -n "\e[35m$2\e[0m" ;;
	cyan) echo -e -n "\e[36m$2\e[0m" ;;
	light-gray) echo -e -n "\e[37m$2\e[0m" ;;
	dark-gray) echo -e -n "\e[90m$2\e[0m" ;;
	light-red) echo -e -n "\e[91m$2\e[0m" ;;
	light-green) echo -e -n "\e[92m$2\e[0m" ;;
	light-yellow) echo -e -n "\e[93m$2\e[0m" ;;
	light-blue) echo -e -n "\e[94m$2\e[0m" ;;
	light-magenta) echo -e -n "\e[95m$2\e[0m" ;;
	light-cyan) echo -e -n "\e[96m$2\e[0m" ;;
	white) echo -e -n "\e[97m$2\e[0m" ;;
	*) echo -e -n "$2" ;;
	esac
}

function display_error() {
	color red "$1\n" >&2
}

function display_progress() {
	color light-blue "$1\n" >&2
}

function display_succes() {
	color light-green "$1\n" >&2
}

function wait_progress() {
	while kill -0 $1 2>/dev/null; do
		sleep .20
	done
}

function wait_all_processes() {
	arr=("$@")
	for pid in "${arr[@]}"; do
			# echo "waiting for $pid"
			wait $pid
		done
}

ACTIVE_FILE_UPLOADS=()
function upload_files() {
	pushd ${3}
	for file in $(ls -p | grep -v / ); do
		echo "uploading $file"
		az storage blob upload -c "${2}" -f ${file} -n ${file} --connection-string "${1}" &>/dev/null &
    	ACTIVE_FILE_UPLOADS+=($!)
	done
	wait_all_processes ${ACTIVE_FILE_UPLOADS[@]}
	popd
}