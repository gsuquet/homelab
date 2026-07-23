# How to Configure Cloudflare

The `cloudflare` system component runs [cloudflared](https://github.com/cloudflare/cloudflared), a tunnel daemon that exposes internal services to the internet through Cloudflare's network without opening inbound ports on your router.

---

## How It Works

`cloudflared` establishes an outbound tunnel from the cluster to Cloudflare's edge. Cloudflare terminates HTTPS at its edge and forwards traffic through the tunnel to the specified internal services. DNS records pointing to the tunnel are managed in the Cloudflare dashboard.

The deployment is at `kubernetes/system/cloudflare/` and runs a single container:

```yaml
image: cloudflare/cloudflared:2025.11.1
command:
  - tunnel
  - --no-autoupdate
  - run
  - --token
  - $(TOKEN)
```

The `TOKEN` is read from a sealed secret named `cloudflared-credentials`.

---

## Prerequisites

- A Cloudflare account with a domain configured
- A tunnel created in the [Cloudflare Zero Trust dashboard](https://one.dash.cloudflare.com/)
- `kubeseal` installed (see [Manage Secrets](manage-secrets.md))

---

## Step 1: Create the Tunnel and Get the Token

1. Go to **Cloudflare Zero Trust → Networks → Tunnels**
2. Click **Create a tunnel**
3. Choose **Cloudflared** as the connector type
4. Give the tunnel a name (e.g., `homelab`)
5. Copy the tunnel token — it is a long base64 string

---

## Step 2: Create the Sealed Secret

Create a raw Kubernetes secret with the tunnel token:

```bash
kubectl create secret generic cloudflared-credentials \
  --namespace cloudflare \
  --from-literal=TOKEN=<your-tunnel-token> \
  --dry-run=client \
  -o yaml > /tmp/cloudflared-credentials.yaml
```

Seal it:

```bash
kubeseal \
  --namespace cloudflare \
  --format yaml \
  < /tmp/cloudflared-credentials.yaml \
  > kubernetes/system/cloudflare/sealed-secret.yaml
```

Delete the plain secret:

```bash
rm /tmp/cloudflared-credentials.yaml
```

---

## Step 3: Commit and Push

```bash
git add kubernetes/system/cloudflare/sealed-secret.yaml
git commit -m "feat(cloudflare): add cloudflared tunnel credentials"
git push
```

ArgoCD applies the `SealedSecret`. The Sealed Secrets controller decrypts it and creates a `cloudflared-credentials` `Secret` in the `cloudflare` namespace. The `cloudflared` deployment reads `TOKEN` from that secret and connects to Cloudflare.

---

## Step 4: Configure Routing in Cloudflare Dashboard

Back in the Cloudflare Zero Trust dashboard:

1. Go to your tunnel → **Public Hostname** tab
2. Add a hostname for each service you want to expose:
   - **Subdomain**: e.g., `ha`
   - **Domain**: your registered domain
   - **Service**: `http://homeassistant.homeassistant.svc.cluster.local:8123`

Cloudflare creates the DNS record automatically.

---

## Verify the Tunnel

Check that the cloudflared pod is running:

```bash
kubectl get pod -n cloudflare
```

Check the logs for a successful connection:

```bash
kubectl logs -n cloudflare -l app=cloudflared
```

A healthy tunnel shows log lines like:

```bash
Registered tunnel connection connIndex=0
```

In the Cloudflare dashboard, the tunnel status should show **HEALTHY**.
