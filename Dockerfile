FROM debian:bookworm

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

# wkhtmltopdf (保留，因為可能 PHP 需要使用)
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
    php8.3 \
    php8.3-curl \
    php8.3-imap \
    php8.3-gd \
    php8.3-mysql \
    php8.3-mbstring \
    php8.3-xml \
    php8.3-memcached \
    php8.3-cli \
    php8.3-fpm \
    php8.3-zip \
    php8.3-bz2 \
    php8.3-ssh2 \
    php8.3-yaml

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
  cp -f /home/docker/php/default83.ini /etc/php/8.3/docker_setup.ini && \
  ln -s /etc/php/8.3/docker_setup.ini /etc/php/8.3/fpm/conf.d/ && \
  cp -f /home/docker/php/default83_cli.ini /etc/php/8.3/cli/conf.d/ && \
  cp -f /home/docker/php/default_opcache_blacklist /etc/php/8.3/opcache_blacklist && \
  sed -i 's/^listen = .*/listen = 80/g' /etc/php/8.3/fpm/pool.d/www.conf && \
  sed -i 's/^pm = .*/pm = ondemand/g' /etc/php/8.3/fpm/pool.d/www.conf && \
  sed -i 's/;daemonize = .*/daemonize = no/g' /etc/php/8.3/fpm/php-fpm.conf && \
  sed -i 's/^pm\.max_children = .*/pm.max_children = 8/g' /etc/php/8.3/fpm/pool.d/www.conf && \
  sed -i 's/^;pm\.process_idle_timeout = .*/pm.process_idle_timeout = 15s/g' /etc/php/8.3/fpm/pool.d/www.conf && \
  sed -i 's/^;pm\.max_requests = .*/pm.max_requests = 50/g' /etc/php/8.3/fpm/pool.d/www.conf && \
  sed -i 's/^;request_terminate_timeout = .*/request_terminate_timeout = 7200/g' /etc/php/8.3/fpm/pool.d/www.conf

COPY container/rsyslogd/rsyslog.conf /etc/rsyslog.conf
COPY container/supervisord/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
RUN \
  mkdir -p /run/php && chmod 777 /run/php

RUN \
  echo "source /usr/share/vim/vim90/defaults.vim" > /etc/vim/vimrc.local && \
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

COPY container/start.sh /start.sh
RUN chmod +x /start.sh
ENTRYPOINT ["/start.sh"]