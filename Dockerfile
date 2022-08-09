FROM php:apache
LABEL maintainer="Chris Wieringa <cwieri39@calvin.edu>"

# Set versions and platforms
ARG TZ=US/Michigan
ARG BUILDDATE=20220809-01

# Do all run commands with bash
SHELL ["/bin/bash", "-c"]

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

# Expose the services
EXPOSE 80

# Start Apache
#COPY --chmod=0755 inc/launch-apache.sh /root/launch-apache.sh
CMD ["apache2","-DFOREGROUND"]
