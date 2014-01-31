#!/usr/bin/env bash

set -e

NGINX_VERSION="$1"

E_ARG_MISSING=127
E_S3_BUCKET_MISSING=2

basedir="$( cd -P "$( dirname "$0" )" && pwd )"
source "$basedir/../support/set-env.sh"

export PATH=${basedir}/../vendor/bin:$PATH

if [ -z "$NGINX_VERSION" ]; then
    echo "Usage: $0 <version>" >&2
    exit $E_ARG_MISSING
fi

if [ -z "$NGINX_ZLIB_VERSION" ]; then
    NGINX_ZLIB_VERSION=1.2.8
fi

if [ -z "$NGINX_PCRE_VERSION" ]; then
    NGINX_PCRE_VERSION=8.34
fi

zlib_version="$NGINX_ZLIB_VERSION"
pcre_version="$NGINX_PCRE_VERSION"

tempdir="$( mktemp -t nginx_XXXXXXXX )"
rm -rf $tempdir
mkdir -p $tempdir
cd $tempdir

echo "-----> Downloading dependency PCRE ${pcre_version}"


curl -LO "http://sourceforge.net/projects/pcre/files/pcre/${pcre_version}/pcre-${pcre_version}.tar.gz"
tar -xzvf "pcre-${pcre_version}.tar.gz"

curl -LO https://github.com/agentzh/headers-more-nginx-module/archive/v0.25.tar.gz
tar -zxvf v0.25.tar.gz
 
echo "-----> Downloading dependency zlib ${zlib_version}"

#curl -LO "http://${S3_BUCKET}.s3.amazonaws.com/zlib/zlib-${zlib_version}.tar.gz"
curl -LO "http://zlib.net/zlib-${zlib_version}.tar.gz"
tar -xzvf "zlib-${zlib_version}.tar.gz"

echo "-----> Downloading NGINX ${NGINX_VERSION}"

curl -LO "http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz"
tar -xzvf "nginx-${NGINX_VERSION}.tar.gz"

echo "-----> Compiling Nginx"

cd nginx-${NGINX_VERSION}
./configure --prefix=/app/vendor/nginx --add-module=../headers-more-nginx-module-0.25 --with-pcre=../pcre-${pcre_version} --with-zlib=../zlib-${zlib_version} --with-http_ssl_module --with-http_gzip_static_module --with-http_stub_status_module
make
make install
cd /app/vendor/nginx
tar -cvzf $tempdir/nginx-${NGINX_VERSION}.tgz .

"$basedir/checksum.sh" "$tempdir/nginx-${NGINX_VERSION}.tgz"

echo "-----> Done building NGINX package! saved as $tempdir/nginx-${NGINX_VERSION}.tgz"

echo "-----------------------------------------------"

echo "---> Uploading package to FTP Server"
while true; do
    read -p "Do you wish to to Upload to FTP Server (y/n)?" yn
    case ${yn} in
        [Yy]* ) "$basedir/ftp-upload.sh" "$tempdir/nginx-${NGINX_VERSION}.tgz"; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done
