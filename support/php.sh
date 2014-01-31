#!/usr/bin/env bash

set -e

basedir="$( cd -P "$( dirname "$0" )" && pwd )"
source "$basedir/../support/set-env.sh"

export PATH=${basedir}/../vendor/bin:$PATH

if [ -z "$1" ]; then
    echo "Usage: $0 <version>" >&2
    exit 1
fi

php_version="$1"
mcrypt_version="2.5.8"

if [ -z "$PHP_ZLIB_VERSION" ]; then
    PHP_ZLIB_VERSION=1.2.8
fi

echo "-----> Packaging PHP $php_version"

tempdir="$( mktemp -t php_xxxx )"
rm -rf $tempdir
mkdir -p $tempdir
cd $tempdir

echo "-----> Downloading dependency zlib ${zlib_version}"

curl -LO "http://zlib.net/zlib-${zlib_version}.tar.gz"
tar -xzvf "zlib-${PHP_ZLIB_VERSION}.tar.gz"

echo "-----> Downloading PHP $php_version"
curl -LO "http://php.net/distributions/php-${php_version}.tar.gz"
tar -xzvf "php-${php_version}.tar.gz"

mkdir -p "/app/vendor/php/zlib" "/app/vendor/libmcrypt" "/app/vendor/libicu"
curl "http://${S3_BUCKET}.s3.amazonaws.com/package/libicu-51.tgz"
tar xzv -C /app/vendor/libicu
curl "http://${S3_BUCKET}.s3.amazonaws.com/package/libmcrypt-${mcrypt_version}.tgz"
tar xzv -C /app/vendor/libmcrypt
export LD_LIBRARY_PATH=/app/vendor/libicu/lib
export PATH=/app/vendor/libicu/bin:\$PATH
mkdir -p "/app/vendor/php/etc/conf.d"
cd zlib-${PHP_ZLIB_VERSION} && 
./configure --prefix=/app/vendor/php/zlib && make && make install
cd ../php-${php_version}

./configure --prefix=/app/vendor/php \
    --with-config-file-path=/app/vendor/php/etc \
    --with-config-file-scan-dir=/app/vendor/php/etc/conf.d \
    --enable-intl \
    --with-gd \
    --enable-shmop \
    --enable-zip \
    --with-jpeg-dir=/usr \
    --with-png-dir=/usr \
    --enable-exif \
    --with-zlib=/app/vendor/php/zlib \
    --with-bz2 \
    --with-openssl \
    --enable-soap \
    --enable-xmlreader \
    --with-xmlrpc \
    --with-curl=/usr \
    --with-xsl \
    --enable-fpm \
    --enable-mbstring \
    --enable-pcntl \
    --enable-sockets \
    --enable-bcmath \
    --with-readline \
    --with-mcrypt=/app/vendor/libmcrypt \
    --disable-debug \
	--enable-opcache

make && make install

/app/vendor/php/bin/pear config-set php_dir /app/vendor/php

echo "-----> Uploading source to build server"

cd /app/vendor/php
tar -cvzf $tempdir/php-${php_version}.tgz .

"$basedir/checksum.sh" "$tempdir/php-${php_version}.tgz"

echo "-----> Done building PHP package! saved as $tempdir/php-${php_version}.tgz"

echo "-----------------------------------------------"

echo "---> Uploading package to FTP Server"
while true; do
    read -p "Do you wish to to Upload to FTP Server (y/n)?" yn
    case ${yn} in
        [Yy]* ) "$basedir/ftp-upload.sh" "$tempdir/php-${php_version}.tgz"; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

echo "-----> Done building PHP package!"
