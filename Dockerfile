FROM debian:bookworm
MAINTAINER Chang Shu-Huai <junsuwhy@netivism.com.tw>

### locales
ENV LC_CTYPE zh_TW.UTF-8
ENV LANG zh_TW.UTF-8

RUN \
  apt-get update && \
  apt-get install -y locales && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* && \
  sed -e 's|^# en_US.UTF-8|en_US.UTF-8|g' -i /etc/locale.gen && \
  sed -e 's|^# zh_TW.UTF-8|zh_TW.UTF-8|g' -i /etc/locale.gen && \
  echo "LANG=zh_TW.UTF-8" > /etc/default/locale && \
  locale-gen

RUN \
  apt-get upgrade -y

ENV \
  COMPOSER_HOME=/root/.composer \
  PATH=/root/.composer/vendor/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# basic packages install
RUN \
    apt-get update && \
    apt-get install -y rsyslog apt-transport-https wget gnupg gcc make autoconf libc-dev pkg-config google-perftools qpdf curl vim git-core supervisor procps

# add PHP sury
WORKDIR /etc/apt/sources.list.d
RUN \
    echo "deb https://packages.sury.org/php/ bookworm main" > phpsury.list && \
    echo "deb-src https://packages.sury.org/php/ bookworm main" >> phpsury.list && \
    wget -qO /etc/apt/trusted.gpg.d/sury-php.gpg https://packages.sury.org/php/apt.gpg && \
    apt-get update

#mariadb
RUN \
    apt-get install -y wget mariadb-server mariadb-backup mariadb-client

# wkhtmltopdf
WORKDIR /tmp
ENV DEBIAN_FRONTEND=noninteractive
RUN \
  apt-get update && \
  apt-get install -y fonts-droid-fallback fontconfig ca-certificates fontconfig libc6 libfreetype6 libjpeg62-turbo libpng16-16 libstdc++6 libx11-6 libxcb1 libxext6 libxrender1 xfonts-75dpi xfonts-base zlib1g && \
  wget -nv http://security.debian.org/debian-security/pool/updates/main/o/openssl/libssl1.1_1.1.1w-0+deb11u2_amd64.deb -O libssl1.1.deb && \
  dpkg -i libssl1.1.deb && \
  rm -f libssl1.1.deb && \
  wget -nv https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.buster_amd64.deb -O wkhtmltox.deb && \
  dpkg -i wkhtmltox.deb && \
  rm -f wkhtmltox.deb

WORKDIR /
RUN \
  apt-get update && \
  apt-get install -y \
    php8.2 \
    php8.2-curl \
    php8.2-imap \
    php8.2-gd \
    php8.2-mysql \
    php8.2-mbstring \
    php8.2-xml \
    php8.2-memcached \
    php8.2-cli \
    php8.2-fpm \
    php8.2-zip \
    php8.2-bz2 \
    php8.2-ssh2 \
    php8.2-yaml

RUN \
  mkdir -p /usr/local/bin && \
  curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
  composer global require drush/drush:8.4.12 && \
  cd /root/.composer && \
  find . | grep .git | xargs rm -rf && \
  composer clearcache

### PHP FPM Config
# remove default enabled site
RUN \
  mkdir -p /var/www/html/log/supervisor && \
  git clone https://github.com/NETivism/docker-sh.git /home/docker && \
  cp -f /home/docker/php/default82.ini /etc/php/8.2/docker_setup.ini && \
  ln -s /etc/php/8.2/docker_setup.ini /etc/php/8.2/fpm/conf.d/ && \
  cp -f /home/docker/php/default82_cli.ini /etc/php/8.2/cli/conf.d/ && \
  cp -f /home/docker/php/default_opcache_blacklist /etc/php/8.2/opcache_blacklist && \
  sed -i 's/^listen = .*/listen = 80/g' /etc/php/8.2/fpm/pool.d/www.conf && \
  sed -i 's/^pm = .*/pm = ondemand/g' /etc/php/8.2/fpm/pool.d/www.conf && \
  sed -i 's/;daemonize = .*/daemonize = no/g' /etc/php/8.2/fpm/php-fpm.conf && \
  sed -i 's/^pm\.max_children = .*/pm.max_children = 8/g' /etc/php/8.2/fpm/pool.d/www.conf && \
  sed -i 's/^;pm\.process_idle_timeout = .*/pm.process_idle_timeout = 15s/g' /etc/php/8.2/fpm/pool.d/www.conf && \
  sed -i 's/^;pm\.max_requests = .*/pm.max_requests = 50/g' /etc/php/8.2/fpm/pool.d/www.conf && \
  sed -i 's/^;request_terminate_timeout = .*/request_terminate_timeout = 7200/g' /etc/php/8.2/fpm/pool.d/www.conf


COPY container/mysql/mysql-init.sh /usr/local/bin/mysql-init.sh
COPY container/rsyslogd/rsyslog.conf /etc/rsyslog.conf
COPY container/supervisord/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
RUN \
  mkdir -p /run/php && chmod 777 /run/php

RUN \
  echo "source /usr/share/vim/vim82/defaults.vim" > /etc/vim/vimrc.local && \
  echo "let skip_defaults_vim = 1" >> /etc/vim/vimrc.local && \
  echo "if has('mouse')" >> /etc/vim/vimrc.local && \
  echo "  set mouse=" >> /etc/vim/vimrc.local && \
  echo "endif" >> /etc/vim/vimrc.local

### ci tools
ENV \
  PATH=$PATH:/root/phpunit \
  PHANTOMJS_VERSION=1.9.8

RUN \
  apt-get update

# -------
#phpunit
# RUN \
#   mkdir -p /root/phpunit/extensions && \
#   wget -O /root/phpunit/phpunit https://phar.phpunit.de/phpunit-10.phar && \
#   chmod +x /root/phpunit/phpunit && \
#   cp /home/docker/php/phpunit.xml /root/phpunit/ && \
#   echo "alias phpunit='phpunit -c ~/phpunit/phpunit.xml'" > /root/.bashrc

# npm / nodejs
# RUN \
#   cd /tmp && \
#   curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
#   apt-get install -y nodejs && \
#   curl https://www.npmjs.com/install.sh | sh && \
#   node -v && npm -v

# playwright
# RUN \
#   sed -i 's/main$/main contrib non-free/g' /etc/apt/sources.list && apt-get update && \
#   mkdir -p /tmp/playwright && cd /tmp/playwright && \
#   npm install -g -D dotenv && \
#   npm install -g -D @playwright/test && \
#   npx playwright install --with-deps chromium

# cgi
# RUN \
#   apt-get install -y php8.2-cgi net-tools

# purge
# RUN \
#   apt-get remove -y gcc make autoconf libc-dev pkg-config php-pear && \
#   apt-get autoremove -y && \
#   apt-get clean && rm -rf /var/lib/apt/lists/*


### drupal download
COPY container/drupal-download.sh /tmp
COPY container/drupalmodule-download.sh /tmp
RUN \
  chmod +x /tmp/drupal-download.sh && \
  chmod +x /tmp/drupalmodule-download.sh

RUN \
  /tmp/drupal-download.sh 10 && \
  mkdir -p /var/www/html/sites/all/modules && \
  /tmp/drupalmodule-download.sh 10 && \
  mkdir -p /var/www/html/log/supervisor && \
  mkdir -p /mnt/neticrm-10/civicrm

### Add drupal 10 related drush
RUN \
  cd /var/www/html && composer update && composer require drush/drush

# we don't have mysql setup on vanilla image
ADD container/my.cnf /etc/mysql/my.cnf

# override supervisord to prevent conflict
# ADD container/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# add initial script
ADD container/init-10.sh /init.sh

RUN chmod +x /init.sh

WORKDIR /mnt/neticrm-10/civicrm
CMD ["/usr/bin/supervisord"]