#!/bin/bash
# auto healing
HOST_STATUS_SERVICE_FILE=/etc/systemd/system/${PROJECT_NAME}-host-status.service
cat <<-EOF > ${HOST_STATUS_SERVICE_FILE}
[Unit]
Description=run host status 

[Service]
Type=simple
WatchdogSec=3min
RestartSec=1min
Restart=always
ExecStart=${ROOT_DIR}/host/status.sh "${PROJECT_NAME}" "${ROOT_DIR}" "${HOST_TYPE}" "${HOST_ID}" "${HOST_ROLE}" "${STATUS_TOPIC_ID}" "${STORAGE_ACCOUNT_ID}" "${KEYVAULT_ID}"

[Install]
WantedBy=multi-user.target
EOF

# enable service
systemctl daemon-reload
systemctl enable --now ${PROJECT_NAME}-host-status.service
