#!/bin/bash
COREDB_API_SERVICE_FILE=/etc/systemd/system/${PROJECT_NAME}-coredb-api.service
cat <<-EOF > ${COREDB_API_SERVICE_FILE}
[Unit]
Description=run coredb service 
After=syslog.target

[Service]
Type=simple
WatchdogSec=3min
RestartSec=1min
Restart=always
ExecStart=/usr/bin/java -jar ${ROOT_DIR}/host/coredb-api-1.0.0.jar 
SuccessExitStatus=143 

[Install]
WantedBy=multi-user.target
EOF

# enable service
systemctl daemon-reload
systemctl enable --now ${PROJECT_NAME}-coredb-api.service
