#!/bin/bash

# 確保目錄存在
mkdir -p /var/www/html/log/supervisor

# 設置正確的擁有者和權限
chown -R www-data:www-data /var/www/html/log
chmod -R 755 /var/www/html/log

# 啟動 supervisord
exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf