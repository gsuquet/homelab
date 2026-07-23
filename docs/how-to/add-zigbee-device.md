# How to Add a Zigbee Device

Use this guide to pair a new Zigbee device (sensor, switch, bulb, etc.) and make it available in Home Assistant.

---

## Prerequisites

- Zigbee2MQTT is running (`kubectl get pod -n homeassistant -l app=zigbee2mqtt`)
- Home Assistant is running (`kubectl get pod -n homeassistant -l app=homeassistant`)
- The Zigbee2MQTT web UI is accessible (via port-forward or Cloudflare tunnel)

If you need to access the UI locally:

```bash
kubectl port-forward service/zigbee2mqtt 8080:8080 -n homeassistant
```

Then open `http://localhost:8080`.

---

## Step 1: Enable Pairing Mode

In the Zigbee2MQTT web UI:

1. Click the **Permit join** toggle in the top bar
2. The toggle turns green — pairing mode is now active for 254 seconds

Alternatively, enable pairing for a specific device or group to avoid accidentally pairing unintended devices.

---

## Step 2: Pair the Device

Put your Zigbee device into pairing mode. The method varies by manufacturer:

- **Most devices**: Hold the reset/pairing button for 5–10 seconds until an LED blinks
- **Bulbs**: Power-cycle 5–6 times rapidly
- Consult your device's manual if unsure

The device should appear in the Zigbee2MQTT UI within 30 seconds under the **Devices** tab.

---

## Step 3: Find and Name the Device

1. Go to the **Devices** tab in the Zigbee2MQTT UI
2. Find the newly paired device — it will have an auto-generated name based on its IEEE address
3. Click the device and rename it to something meaningful (e.g., `living_room_temperature`)

A friendly name makes it easier to identify in Home Assistant automations.

---

## Step 4: Verify MQTT Messages

Zigbee2MQTT publishes device state to Mosquitto on the topic `zigbee2mqtt/<device-name>`. You can verify the messages are flowing by checking the Zigbee2MQTT logs:

```bash
kubectl logs -n homeassistant -l app=zigbee2mqtt --tail=50
```

---

## Step 5: Use the Device in Home Assistant

Zigbee2MQTT is configured with Home Assistant MQTT discovery enabled:

```text
ZIGBEE2MQTT_CONFIG_HOMEASSISTANT_ENABLED: 'true'
ZIGBEE2MQTT_CONFIG_HOMEASSISTANT_DISCOVERY_TOPIC: homeassistant
```

This means Home Assistant automatically discovers the device and creates entities for it. No manual configuration is needed.

To verify:

1. Open Home Assistant
2. Go to **Settings → Devices & Services → MQTT**
3. The new device should appear with its entities (e.g., temperature, battery, occupancy)

---

## Pairing Mode and Persistent Configuration

The list of paired devices is stored in the `zigbee2mqtt-data` PVC at `/app/data/`. This means device pairings survive pod restarts and redeployments.

The coordinator is a network-attached Zigbee USB adapter exposed over TCP:

```text
ZIGBEE2MQTT_CONFIG_SERIAL_PORT: tcp://192.168.1.28:6638
ZIGBEE2MQTT_CONFIG_SERIAL_ADAPTER: ember
```

If the coordinator's IP address changes, update the `zigbee2mqtt-config` ConfigMap in `kubernetes/applications/zigbee2mqtt/configmap.yaml`.
