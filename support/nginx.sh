#!/usr/bin/env bash

set -e

nginx_version="$1"

E_ARG_MISSING=127
E_S3_BUCKET_MISSING=2

basedir="$( cd -P "$( dirname "$0" )" && pwd )"
source "$basedir/../conf/buildpack.conf"

export PATH=${basedir}/../vendor/bin:$PATH

if [ -z "$nginx_version" ]; then
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

echo "-----> Downloading NGINX ${nginx_version}"

curl -LO "http://nginx.org/download/nginx-${nginx_version}.tar.gz"
tar -xzvf "nginx-${nginx_version}.tar.gz"

echo "-----> Compiling Nginx"

cd nginx-${nginx_version}
./configure --prefix=/app/vendor/nginx --add-module=../headers-more-nginx-module-0.25 --with-http_ssl_module --with-pcre=../pcre-${pcre_version} --with-zlib=../zlib-${zlib_version}
make
make install
cd /app/vendor/nginx
tar -cvzf $tempdir/nginx-${nginx_version}.tgz .

"$basedir/package-checksum" "$tempdir/nginx-${nginx_version}.tgz"

echo "-----> Done building NGINX package! saved as $tempdir/nginx-${nginx_version}.tgz"

echo "-----------------------------------------------"

echo "---> Uploading package to FTP Server"
while true; do
    read -p "Do you wish to to Upload to FTP Server (y/n)?" yn
    case ${yn} in
        [Yy]* ) "$basedir/ftp-upload" "$tempdir/nginx-${nginx_version}.tgz"; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done