#!/bin/bash
cd reverse-proxy
docker compose up -d
cd ../admin
docker compose up -d
cd ../monitoring
docker compose up -d
