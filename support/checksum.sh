#!/usr/bin/env bash

set -e

basedir="$( cd -P "$( dirname "$0" )" && pwd )"
source "$basedir/../support/set-env.sh"

package="$1"

echo "--> Creating checksum for ${package}"

md5sum -b "${package}" > "${package}.md5"
echo "----> File MD5 checksum ${package}.md5"
