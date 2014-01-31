#!/bin/bash

## EDIT
source ./set-env.sh
## END EDIT

set -e

if [ "$PHP_VERSION" == "" ]; then
  echo "must set PHP_VERSION, i.e PHP_VERSION=5.5.8"
  exit 1
fi

DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

set -o pipefail

orig_dir=$( pwd )

mkdir -p build && pushd build

echo "+ Fetching libmcrypt libraries..."
# install mcrypt for portability.
mkdir -p /app/local
curl -L "https://s3.amazonaws.com/${S3_BUCKET}/libmcrypt-${LIBMCRYPT_VERSION}.tar.gz" -o - | tar xz -C /app/local

echo "+ Fetching freetype libraries..."
mkdir -p /app/local
curl -L "http://download.savannah.gnu.org/releases/freetype/freetype-${LIFREETYPE_VERSION}.tar.gz" -o - | tar xz -C /app/local

echo "+ Fetching PHP sources..."
#fetch php, extract
curl -L http://us.php.net/get/php-$PHP_VERSION.tar.bz2/from/www.php.net/mirror -o - | tar xj

pushd php-$PHP_VERSION

echo "+ Configuring PHP..."
# new configure command
## WARNING: libmcrypt needs to be installed.
./configure \
--prefix=/app/vendor/php \
--with-config-file-path=/app/vendor/php \
--with-config-file-scan-dir=/app/vendor/php/etc.d \
--disable-debug \
--disable-rpath \
--enable-fpm \
--enable-gd-native-ttf \
--enable-inline-optimization \
--enable-libxml \
--enable-mbregex \
--enable-mbstring \
--enable-pcntl \
--enable-soap=shared \
--enable-zip \
--with-bz2 \
--with-curl \
--with-gd \
--with-gettext \
--with-jpeg-dir \
--with-mcrypt=/app/local \
--with-iconv \
--with-mhash \
--with-mysql \
--with-mysqli \
--with-openssl \
--with-pcre-regex \
--with-pdo-mysql \
--with-pgsql \
--with-pdo-pgsql \
--with-png-dir \
--with-freetype-dir=/app/local \
--with-zlib

echo "+ Compiling PHP..."
# build & install it
make install

popd

# update path
export PATH=/app/vendor/php/bin:$PATH

# configure pear
pear config-set php_dir /app/vendor/php


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

echo "+ Install newrelic..."
curl -L "http://download.newrelic.com/php_agent/archive/${NEWRELIC_VERSION}/newrelic-php5-${NEWRELIC_VERSION}-linux.tar.gz" | tar xz
pushd newrelic-php5-${NEWRELIC_VERSION}-linux
cp -f agent/x64/newrelic-`phpize --version | grep "Zend Module Api No" | tr -d ' ' | cut -f 2 -d ':'`.so `php-config --extension-dir`/newrelic.so
popd

echo "+ Packaging PHP..."
# package PHP
echo ${PHP_VERSION} > /app/vendor/php/VERSION

popd

echo "+ Done!"

