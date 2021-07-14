#!/bin/bash

docker-compose exec postgres psql -U sensors -c "$(cat db/schema.sql)"
