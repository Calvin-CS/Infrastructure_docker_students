FROM php:apache
LABEL maintainer="Chris Wieringa <cwieri39@calvin.edu>"

# Set versions and platforms
ARG S6_OVERLAY_VERSION=3.1.3.0
ARG TZ=US/Michigan
ARG BUILDDATE=20230210-3

# Do all run commands with bash
SHELL ["/bin/bash", "-c"]

# add a few system packages for SSSD/authentication
RUN apt update -y && \
    DEBIAN_FRONTEND=noninteractive apt install -y \
    sssd \
    sssd-ad \
    sssd-krb5 \
    sssd-tools \
    libnfsidmap2 \
    libsss-idmap0 \
    libsss-nss-idmap0 \
    libnss-myhostname \
    libnss-mymachines \
    libnss-ldap \
    libuser \
    locales \
    nfs-common \
    krb5-user \
    sssd-krb5 \
    coreutils && \
    rm -f /var/lib/apt/lists/deb.debian.org*

# add CalvinAD trusted root certificate
ADD https://raw.githubusercontent.com/Calvin-CS/Infrastructure_configs/main/auth/CalvinCollege-ad-CA.crt /etc/ssl/certs
RUN chmod 0644 /etc/ssl/certs/CalvinCollege-ad-CA.crt
RUN ln -s -f /etc/ssl/certs/CalvinCollege-ad-CA.crt /etc/ssl/certs/ddbc78f4.0

# Drop all inc/ configuration files
# krb5.conf, sssd.conf, idmapd.conf
ADD https://raw.githubusercontent.com/Calvin-CS/Infrastructure_configs/main/auth/krb5.conf /etc
ADD https://raw.githubusercontent.com/Calvin-CS/Infrastructure_configs/main/auth/nsswitch.conf /etc
ADD https://raw.githubusercontent.com/Calvin-CS/Infrastructure_configs/main/auth/sssd.conf /etc/sssd
ADD https://raw.githubusercontent.com/Calvin-CS/Infrastructure_configs/main/auth/idmapd.conf /etc
RUN chmod 0600 /etc/sssd/sssd.conf && \
    chmod 0644 /etc/krb5.conf && \
    chmod 0644 /etc/nsswitch.conf && \
    chmod 0644 /etc/idmapd.conf
RUN chown root:root /etc/sssd/sssd.conf

# pam configs
ADD https://raw.githubusercontent.com/Calvin-CS/Infrastructure_configs/main/auth/common-auth /etc/pam.d
ADD https://raw.githubusercontent.com/Calvin-CS/Infrastructure_configs/main/auth/common-session /etc/pam.d
RUN chmod 0644 /etc/pam.d/common-auth && \
    chmod 0644 /etc/pam.d/common-session

# use the secrets to edit sssd.conf appropriately
RUN --mount=type=secret,id=LDAP_BIND_USER \
    source /run/secrets/LDAP_BIND_USER && \
    sed -i 's@%%LDAP_BIND_USER%%@'"$LDAP_BIND_USER"'@g' /etc/sssd/sssd.conf
RUN --mount=type=secret,id=LDAP_BIND_PASSWORD \
    source /run/secrets/LDAP_BIND_PASSWORD && \
    sed -i 's@%%LDAP_BIND_PASSWORD%%@'"$LDAP_BIND_PASSWORD"'@g' /etc/sssd/sssd.conf
RUN --mount=type=secret,id=DEFAULT_DOMAIN_SID \
    source /run/secrets/DEFAULT_DOMAIN_SID && \
    sed -i 's@%%DEFAULT_DOMAIN_SID%%@'"$DEFAULT_DOMAIN_SID"'@g' /etc/sssd/sssd.conf

# Setup multiple stuff going on in the container instead of just single access  -------------------------#
# S6 overlay from https://github.com/just-containers/s6-overlay
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz && \
    tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz && \
    rm -f /tmp/s6-overlay-*.tar.xz

ENV S6_CMD_WAIT_FOR_SERVICES=1 S6_CMD_WAIT_FOR_SERVICES_MAXTIME=5000

ENTRYPOINT ["/init"]
COPY s6-overlay/ /etc/s6-overlay

# Access control
RUN echo "ldap_access_filter = memberOf=CN=CS-Admins,OU=Groups,OU=CalvinCS,DC=ad,DC=calvin,DC=edu" >> /etc/sssd/sssd.conf

# Set timezone
RUN ln -snf /usr/share/zoneinfo/"$TZ" /etc/localtime && \
    echo "$TZ" > /etc/timezone

# Apache environment variables
ENV APACHE_RUN_USER www-data
ENV APACHE_RUN_GROUP www-data
ENV APACHE_LOG_DIR /var/log/apache2
ENV APACHE_PID_FILE /var/run/apache2/apache2.pid
ENV APACHE_RUN_DIR /var/lib/apache/runtime
RUN mkdir -p /var/run/apache2 ${APACHE_RUN_DIR} 

# Update Apache enabled modules configuration
RUN /usr/sbin/a2enmod userdir && \
    /usr/sbin/a2enmod cgi && \
    /usr/sbin/a2enmod headers && \
    /usr/sbin/a2enmod rewrite

# Drop updated Apache configuration file
RUN rm -f /etc/apache2/sites-enabled/000-default.conf
COPY --chmod=0644 inc/students.cs.calvin.edu-http.conf /etc/apache2/sites-enabled/000-default.conf

# Drop HTML documents
COPY --chmod=0644 inc/index.html /var/www/html/index.html
COPY --chmod=0644 inc/readdirections.html /var/www/html/readdirections.html
COPY --chmod=0644 inc/test.php /var/www/html/test.php

# Additional packages for CGI support
RUN apt update -y && \
    DEBIAN_FRONTEND=noninteractive apt install -y \
    libcgi-pm-perl && \
    rm -f /var/lib/apt/lists/deb.debian.org*

# Add additional PHP extension support
# https://github.com/mlocati/docker-php-extension-installer
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/
RUN chmod +x /usr/local/bin/install-php-extensions && \
    install-php-extensions pgsql

# Expose the services
EXPOSE 80

# Locale and environment setup
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8
ENV TERM xterm-256color
