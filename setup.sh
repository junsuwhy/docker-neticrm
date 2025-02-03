#!/usr/bin/bash
docker run -d --name neticrm -p 8080:8080 \
 -v /mnt/neticrm-10/civicrm:/mnt/neticrm-10/civicrm \
 -v $(pwd)/container/init-10.sh:/init.sh \
 -e "DRUPAL=10" \
 -e "TZ=Asia/Taipei" \
 -e "RUNPORT=8080" \
 -e "DRUPAL_ROOT=/var/www/html" \
 -e "CIVICRM_TEST_DSN=mysql://root@localhost/neticrm" junsuwhy/debian-neticrm:php83-d10