FROM php:8.3-apache

RUN apt-get update \
    && apt-get install -y --no-install-recommends libpq-dev \
    && docker-php-ext-install pdo_pgsql \
    && a2enmod rewrite headers

COPY apache.conf /etc/apache2/sites-available/000-default.conf
COPY public/ /var/www/html/

RUN chown -R www-data:www-data /var/www/html
