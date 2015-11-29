#!/bin/bash

sudo apt-get update -y
sudo apt-get install -y apache2 git php5 php5-curl mysql-client curl

git clone https://github.com/LuanaVSantos/env-setup.git

cp ./env-setup/images /var/www/html/images
cp ./env-setup/index.html /var/www/html
cp ./env-setup/*.php /var/www/html

curl -sS https://getcomposer.org/installer | php

php composer.phar require aws/aws-sdk-php

cp vendor /var/www/html

echo "Hello!" > /tmp/hello.txt
