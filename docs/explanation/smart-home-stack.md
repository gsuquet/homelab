# Explanation: Smart Home Stack

This document explains how the three smart home components — Zigbee2MQTT, Mosquitto, and Home Assistant — work together to bridge physical Zigbee devices to automations and a user interface.

---

## The Three Components

### Zigbee2MQTT

Zigbee2MQTT is a bridge between the Zigbee radio protocol and MQTT (a lightweight publish/subscribe messaging protocol). It:

- Communicates with a physical Zigbee coordinator (a USB or network-attached radio dongle)
- Speaks the Zigbee protocol to paired devices (sensors, switches, bulbs, etc.)
- Translates Zigbee device events and states into MQTT messages
- Publishes device state to Mosquitto on topics like `zigbee2mqtt/<device-name>`
- Receives commands from Mosquitto (e.g., turn on a light) on topics like `zigbee2mqtt/<device-name>/set`

In this cluster, Zigbee2MQTT connects to a network-attached Zigbee coordinator at `tcp://192.168.1.28:6638` using the Ember/EZSP adapter protocol.

### Mosquitto

Mosquitto is an MQTT message broker. It:

- Receives MQTT messages published by Zigbee2MQTT (device states)
- Receives MQTT messages published by Home Assistant (commands, discovery)
- Routes messages to subscribers based on topic subscriptions
- Acts as the central message bus that decouples producers from consumers

Mosquitto runs with authentication required — all clients (Zigbee2MQTT, Home Assistant, etc.) must provide a username and password. In this cluster it listens on port 8883.

### Home Assistant

Home Assistant is the automation platform and user interface. It:

- Subscribes to Mosquitto topics via MQTT integration
- Auto-discovers Zigbee devices using Zigbee2MQTT's Home Assistant discovery feature
- Creates entities (sensors, switches, etc.) for each discovered device
- Provides a web UI, mobile app, and automation engine
- Can send commands back to devices by publishing to `zigbee2mqtt/<device-name>/set` via Mosquitto

---

## Data Flow

```ascii
Zigbee Device                Zigbee2MQTT              Mosquitto            Home Assistant
(sensor/switch)              (bridge)                 (broker)             (automation hub)
      │                           │                       │                      │
      │  Zigbee radio             │                       │                      │
      │ ─────────────────────────►│                       │                      │
      │  (state change event)     │                       │                      │
      │                           │  MQTT publish         │                      │
      │                           │ ─────────────────────►│                      │
      │                           │  zigbee2mqtt/<name>   │                      │
      │                           │                       │  MQTT deliver        │
      │                           │                       │ ─────────────────────►
      │                           │                       │  (entity state       │
      │                           │                       │   update)            │
      │                           │                       │                      │
      │                           │                       │     MQTT publish     │
      │                           │◄──────────────────────│◄─────────────────────│
      │  Zigbee command           │  zigbee2mqtt/<name>   │  (automation        │
      │◄──────────────────────────│  /set                 │   command)           │
      │  (turn on/off)            │                       │                      │
```

The flow for a temperature sensor reporting a reading:

1. The sensor broadcasts a Zigbee frame with the new temperature value
2. The Zigbee coordinator receives the frame and forwards it to Zigbee2MQTT
3. Zigbee2MQTT decodes the Zigbee frame and publishes `{"temperature": 21.5}` to the MQTT topic `zigbee2mqtt/living_room_temperature`
4. Mosquitto receives the message and delivers it to all subscribers of that topic
5. Home Assistant is subscribed to `zigbee2mqtt/+` and receives the message
6. Home Assistant updates the `sensor.living_room_temperature` entity value to 21.5 °C

---

## How the Components Are Wired Together

All three components run in the same Kubernetes namespace (`homeassistant`) and communicate over the cluster network using Kubernetes DNS:

| Connection | Address |
| ---------- | ------- |
| Zigbee2MQTT → Mosquitto | `mqtt://mosquitto.homeassistant.svc.cluster.local:8883` |
| Home Assistant → Mosquitto | `mqtt://mosquitto.homeassistant.svc.cluster.local:1883` (default HA MQTT integration) |
| Zigbee2MQTT web UI | `http://zigbee2mqtt.homeassistant.svc.cluster.local:8080` |

Zigbee2MQTT is configured with Home Assistant discovery enabled:

```text
ZIGBEE2MQTT_CONFIG_HOMEASSISTANT_ENABLED: 'true'
ZIGBEE2MQTT_CONFIG_HOMEASSISTANT_DISCOVERY_TOPIC: homeassistant
ZIGBEE2MQTT_CONFIG_HOMEASSISTANT_STATUS_TOPIC: homeassistant/status
```

When a new device is paired with Zigbee2MQTT, it publishes a discovery message to the `homeassistant/` MQTT topic. Home Assistant picks this up via its MQTT integration and automatically creates the appropriate entities — no manual Home Assistant configuration is needed for new Zigbee devices.

---

## Persistent Storage

Each component stores its state on a PVC:

| Component | PVC | Size | What it stores |
| --------- | --- | ---- | -------------- |
| Zigbee2MQTT | `zigbee2mqtt-data` | 1 Gi | Paired device database, network map |
| Mosquitto | `mosquitto-data` | 5 Gi | Queued/persisted MQTT messages |
| Home Assistant | `homeassistant-pvc-config` | 10 Gi | Configuration, automations, history |

Paired Zigbee devices survive pod restarts because Zigbee2MQTT stores the pairing database in its PVC.
