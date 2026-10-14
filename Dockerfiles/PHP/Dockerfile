FROM php:8.3-cli

RUN apt-get update \
 && apt-get install -y --no-install-recommends git unzip \
 && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
ENV COMPOSER_ALLOW_SUPERUSER=1

COPY Gauntlets/ /gauntlet/

# Gauntlet tools live in /gauntlet/php/vendor, separate from the project's vendor/
RUN composer install --working-dir=/gauntlet/php --no-dev --no-interaction --no-progress \
 && chmod +x /gauntlet/php_gauntlet.sh

ENV PATH="/gauntlet/php/vendor/bin:${PATH}"

WORKDIR /workspace