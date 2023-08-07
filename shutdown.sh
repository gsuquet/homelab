#!/bin/bash
cd reverse-proxy
docker compose down
cd ../admin
docker compose down
cd ../monitoring
docker compose down
