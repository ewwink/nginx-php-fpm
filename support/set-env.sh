#!/bin/bash

export S3_BUCKET="heroku-buildpack-php-tyler"

export LIBMCRYPT_VERSION="2.5.8"
export LIFREETYPE_VERSION="2.4.12"
export PHP_VERSION="5.5.8"
export PHPREDIS_VERSION="2.2.2"
export NEWRELIC_VERSION="4.4.5.35"

export NGINX_VERSION="1.5.9"

export EC2_PRIVATE_KEY=~/.ec2/pk.pem
export EC2_CERT=~/.ec2/cert.pem
export EC2_URL=https://ec2.us-east-1.amazonaws.com
