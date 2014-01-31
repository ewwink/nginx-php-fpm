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

install_zend_optimizer=":"

if [[ "$php_version" =~ 5.5 ]]; then
    install_zend_optimizer=$(cat << SH
    echo "zend_extension=opcache.so" >> /app/vendor/php/etc/conf.d/opcache.ini
SH
)
else
    install_zend_optimizer=$(cat <<SH
    /app/vendor/php/bin/pecl install ZendOpcache-beta \
        && echo "zend_extension=\$(/app/vendor/php/bin/php-config --extension-dir)/opcache.so" >> /app/vendor/php/etc/conf.d/opcache.ini
SH
)
fi

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
$install_zend_optimizer
yes '' | /app/vendor/php/bin/pecl install apcu-beta
echo "extension=apcu.so" > /app/vendor/php/etc/conf.d/apcu.ini

echo "-----> Uploading source to build server"

"$basedir/manifest" php
"$basedir/package-checksum" "php-${php_version}"

echo "-----> Done building PHP package!"
