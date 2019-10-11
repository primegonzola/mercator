#!/bin/bash
# assure proper format
dos2unix *.*
# set proper permissions
chmod +x *.sh
# prepare archive
tar -czvf ../host.tar.gz .
# upload archive to final destination
az storage blob upload -c ${2} -f ../host.tar.gz -n host.tar.gz --connection-string "${1}"
# clean up
rm -rf ../host.tar.gz
