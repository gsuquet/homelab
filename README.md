# HomeLab

### Startup
```bash
docker compose -f ./admin/docker-compose.yml -f ./monitoring/docker-compose.yml -f ./reverse-proxy/docker-compose.yml -f up -d
```

### Shutdown
```bash
docker compose -f ./admin/docker-compose.yml -f ./monitoring/docker-compose.yml -f ./reverse-proxy/docker-compose.yml -f down
```
