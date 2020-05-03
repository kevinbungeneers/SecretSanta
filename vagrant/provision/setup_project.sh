#! /usr/bin/env bash

docker run -t -v /vagrant:/usr/src/secretsanta node yarn
docker exec -t app composer install --no-interaction
docker exec -t app bin/console doctrine:schema:up --force