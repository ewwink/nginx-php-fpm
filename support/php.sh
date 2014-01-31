#!/usr/bin/env bash

set -e

basedir="$( cd -P "$( dirname "$0" )" && pwd )"
source "$basedir/../support/set-env.sh"

export PATH=${basedir}/../vendor/bin:$PATH

if [ -z "$PHP_VERSION" ]; then
    echo "Usage: $0 <version>" >&2
    exit 1
fi

mcrypt_version="2.5.8"

if [ -z "$PHP_ZLIB_VERSION" ]; then
    PHP_ZLIB_VERSION=1.2.8
fi

echo "-----> Packaging PHP $PHP_VERSION"

tempdir="$( mktemp -t php_XXXXXXXXX )"
rm -rf $tempdir
mkdir -p $tempdir
cd $tempdir

echo "-----> Downloading dependency zlib ${PHP_ZLIB_VERSION}"

curl -LO "http://zlib.net/zlib-${PHP_ZLIB_VERSION}.tar.gz"
tar -xzvf "zlib-${PHP_ZLIB_VERSION}.tar.gz"

echo "-----> Downloading PHP $PHP_VERSION"
curl -LO "http://php.net/distributions/php-${PHP_VERSION}.tar.gz"
tar -xzvf "php-${PHP_VERSION}.tar.gz"

mkdir -p "/app/vendor/php/zlib" "/app/vendor/libmcrypt"

curl "http://chh-heroku-buildpack-php.s3.amazonaws.com/package/libmcrypt-${mcrypt_version}.tgz" | tar xzv -C /app/vendor/libmcrypt

mkdir -p "/app/vendor/php/etc/conf.d"
cd zlib-${PHP_ZLIB_VERSION} && 
./configure --prefix=/app/vendor/php/zlib && make && make install
cd ../php-${PHP_VERSION}

./configure --disable-all \
			--prefix=/app/vendor/php \
			--with-config-file-path=/app/vendor/php/etc \
			--with-config-file-scan-dir=/app/vendor/php/etc.d \
			--with-gd --with-zlib=/app/vendor/php/zlib \
			--with-openssl \
			--with-curl= \
			--enable-fpm \
			--enable-mbregex \
			--enable-mbstring \
			--enable-sockets \
			--with-mcrypt=/app/vendor/libmcrypt \
			--disable-debug \
			--enable-opcache \
			--with-iconv \
			--with-mysqli \
			--enable-mysqlnd \
			--enable-session \
			--enable-json \
			--enable-filter \
			--enable-fileinfo \
			--enable-libxml

make 
make install

export PATH=/app/vendor/php/bin:$PATH

#/app/vendor/php/bin/pear config-set php_dir /app/vendor/php

echo "+ Installing phpredis..."
# install phpredis
git clone git://github.com/nicolasff/phpredis.git
pushd phpredis
git checkout ${PHPREDIS_VERSION}

phpize
./configure
make && make install
# add "extension=redis.so" to php.ini
popd



echo "-----> Uploading source to build server"

cd /app/vendor/php
tar -cvzf $tempdir/php-${PHP_VERSION}-with-fpm.tgz .

"$basedir/checksum.sh" "$tempdir/php-${PHP_VERSION}-with-fpm.tgz"

echo "-----> Done building PHP package! saved as $tempdir/php-${PHP_VERSION}-with-fpm.tgz"

echo "-----------------------------------------------"

echo "---> Uploading package to FTP Server"
while true; do
    read -p "Do you wish to to Upload to FTP Server (y/n)?" yn
    case ${yn} in
        [Yy]* ) "$basedir/ftp-upload.sh" "$tempdir/php-${PHP_VERSION}-with-fpm.tgz"; break;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

echo "-----> Done building PHP package!"
