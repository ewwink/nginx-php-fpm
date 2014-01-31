#!/usr/bin/env bash

set -e

basedir="$( cd -P "$( dirname "$0" )" && pwd )"
source "$basedir/../support/set-env.sh"
package="$1"

read -p "Enter your FTP user: " FTP_USER
read -p "Enter your FTP password: " FTP_PASS
if [ ${FTP_USER} ] && [ ${FTP_PASS} ]; then
	curl -v -T ${package} ftp://${FTP_HOST}${FTP_DIR} --user ${FTP_USER}:${FTP_PASS}
	echo "-----> File Uploading complete to re-run ftp-upload run command below"
	echo ""
	echo "support/ftp-upload.sh ${package}"
	echo ""
else
	echo "FTP User or Password is empty, File Uploading cancelled... to re-run ftp-upload run command below"
	echo ""
	echo "support/ftp-upload.sh ${package}"
	echo ""
fi
