# Reference: Applications

All applications are deployed to the cluster via ArgoCD. Each application lives under `kubernetes/applications/<name>/`.

---

## Application Overview

| Application | Version | Namespace | Port | Storage | Purpose |
| ----------- | ------- | --------- | ---- | ------- | ------- |
| Home Assistant | 2026.8.0 | `homeassistant` | 8123 | 10 Gi | Smart home automation hub |
| Mosquitto | 2.0.22 | `homeassistant` | 8883 | 5 Gi | MQTT message broker |
| Zigbee2MQTT | 2.7.0 | `homeassistant` | 8080 | 1 Gi | Zigbee-to-MQTT bridge |
| ActualBudget | 25.12.0 | `actualbudget` | 5006 | 1 Gi | Personal finance manager |

---

## Home Assistant

**Path**: `kubernetes/applications/homeassistant/`
**Image**: `ghcr.io/home-assistant/home-assistant:2026.8.0`
**Namespace**: `homeassistant`

### Ports

| Port | Protocol | Purpose |
| ---- | -------- | ------- |
| 8123 | HTTP | Web UI and API |

### Persistent Storage

| PVC Name | Size | Mount Path | Purpose |
| -------- | ---- | ---------- | ------- |
| `homeassistant-pvc-config` | 10 Gi | `/config` | All HA configuration and state |

### Environment Variables

| Variable | Value |
| -------- | ----- |
| `TZ` | `Europe/Paris` |

### Notable Configuration

- Configuration file mounted as a ConfigMap at `/config/configuration.yaml`
- HTTP integration trusts the cluster pod CIDR `10.42.0.0/16` as a proxy (required when behind an ingress or tunnel)
- Default HA configuration with separate files for automations, scripts, and scenes

### Health Probes

| Probe | Type | Port | Interval | Timeout | Startup Retries |
| ----- | ---- | ---- | -------- | ------- | --------------- |
| Liveness | TCP | 8123 | 10s | 1s | — |
| Readiness | TCP | 8123 | 10s | 1s | — |
| Startup | TCP | 8123 | 5s | — | 30 |

---

## Mosquitto

**Path**: `kubernetes/applications/mosquitto/`
**Image**: `eclipse-mosquitto:2.0.22`
**Namespace**: `homeassistant`

### Ports

| Port | Protocol | Purpose |
| ---- | -------- | ------- |
| 8883 | MQTT | Authenticated MQTT connections |
| 9001 | WebSocket | MQTT over WebSocket |

### Persistent Storage

| PVC Name | Size | Mount Path | Purpose |
| -------- | ---- | ---------- | ------- |
| `mosquitto-data` | 5 Gi | `/mosquitto/data` | Message persistence |

### Configuration

- Anonymous access disabled — all clients must authenticate
- Password file mounted from ConfigMap `mosquitto-cm-passwords`
- Configured users: `admin`, `homeassistant`, `netalertx`, `zigbee2mqtt`
- Persistence enabled (messages survive restarts)
- Protocol: standard MQTT (not WebSocket on the primary port)

---

## Zigbee2MQTT

**Path**: `kubernetes/applications/zigbee2mqtt/`
**Image**: `ghcr.io/koenkk/zigbee2mqtt:2.7.0`
**Namespace**: `homeassistant`

### Ports

| Port | Protocol | Purpose |
| ---- | -------- | ------- |
| 8080 | HTTP | Web UI (zigbee2mqtt-windfront) |

### Persistent Storage

| PVC Name | Size | Mount Path | Purpose |
| -------- | ---- | ---------- | ------- |
| `zigbee2mqtt-data` | 1 Gi | `/app/data` | Device database and configuration |

### Environment Variables

| Variable | Value |
| -------- | ----- |
| `TZ` | `Europe/Paris` |
| `ZIGBEE2MQTT_CONFIG_MQTT_SERVER` | `mqtt://mosquitto.homeassistant.svc.cluster.local:8883` |
| `ZIGBEE2MQTT_CONFIG_MQTT_USER` | `zigbee2mqtt` |
| `ZIGBEE2MQTT_CONFIG_MQTT_PASSWORD` | *(sealed secret)* |
| `ZIGBEE2MQTT_CONFIG_SERIAL_PORT` | `tcp://192.168.1.28:6638` |
| `ZIGBEE2MQTT_CONFIG_SERIAL_ADAPTER` | `ember` |
| `ZIGBEE2MQTT_CONFIG_SERIAL_BAUDRATE` | `115200` |
| `ZIGBEE2MQTT_CONFIG_ADVANCED_CHANNEL` | `15` |
| `ZIGBEE2MQTT_CONFIG_ADVANCED_TRANSMIT_POWER` | `20` |
| `ZIGBEE2MQTT_CONFIG_HOMEASSISTANT_ENABLED` | `true` |
| `ZIGBEE2MQTT_CONFIG_HOMEASSISTANT_DISCOVERY_TOPIC` | `homeassistant` |
| `ZIGBEE2MQTT_CONFIG_FRONTEND_ENABLED` | `true` |

### Notable Configuration

- Connects to a network-attached Zigbee coordinator at `tcp://192.168.1.28:6638` (Ember/EZSP adapter)
- MQTT password stored in a `SealedSecret` (`zigbee2mqtt-secrets`)
- Home Assistant MQTT discovery enabled — devices auto-appear in HA

---

## ActualBudget

**Path**: `kubernetes/applications/actualbudget/`
**Image**: `ghcr.io/actualbudget/actual:25.12.0-alpine`
**Namespace**: `actualbudget`

### Ports

| Port | Protocol | Purpose |
| ---- | -------- | ------- |
| 5006 | HTTP | Web UI |

### Persistent Storage

| PVC Name | Size | Mount Path | Purpose |
| -------- | ---- | ---------- | ------- |
| `actualbudget-pvc-data` | 1 Gi | `/data` | Budget databases and sync state |

### Notable Configuration

- Self-contained: no external dependencies or credentials required
- All budget data stored locally in the PVC
