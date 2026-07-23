# Explanation: Secret Management

This document explains why plain Kubernetes Secrets cannot be committed to Git, and how this project uses Sealed Secrets to solve that problem.

---

## The Problem with Kubernetes Secrets in Git

A Kubernetes `Secret` stores sensitive data (passwords, tokens, API keys) in `data` fields that are base64-encoded:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-app-secret
data:
  PASSWORD: xxxxxxxxxxxxxxxx  # "supersecret" in base64
```

Base64 is **not encryption** — it is trivially reversible. Committing this YAML to a public (or shared) Git repository exposes the password to anyone with read access to the repo. Even in a private repository, this is bad practice because:

- Any historical commit with a leaked secret is permanent
- Git history is shared with everyone who clones the repo
- Access control on the repo and access control on the secret become coupled

---

## How Sealed Secrets Works

[Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) uses asymmetric encryption to solve this:

1. The **Sealed Secrets controller** runs in the cluster and generates an RSA key pair at startup
2. The **public key** is available to anyone (used to encrypt secrets)
3. The **private key** never leaves the cluster (used to decrypt secrets)

When you want to store a secret in Git:

1. You write the plain `Secret` locally (never committed)
2. You encrypt it with `kubeseal` using the cluster's public key → produces a `SealedSecret` object
3. You commit the `SealedSecret` to Git — it is safe because only the cluster's private key can decrypt it
4. ArgoCD applies the `SealedSecret` to the cluster
5. The Sealed Secrets controller decrypts it and creates a standard Kubernetes `Secret` in the same namespace

```ascii
Developer workstation                              Kubernetes cluster
┌──────────────────────┐                          ┌──────────────────────────┐
│  plain Secret (YAML) │                          │  Sealed Secrets          │
│  (never committed)   │                          │  Controller              │
└──────────┬───────────┘                          │                          │
           │ kubeseal                             │  private key             │
           │ (encrypts with public key)           │  (never leaves cluster)  │
           ▼                                      └──────────┬───────────────┘
┌──────────────────────┐                                     │ decrypts
│  SealedSecret (YAML) │  →  Git  →  ArgoCD applies  →      ▼
│  (safe to commit)    │                          ┌──────────────────────────┐
└──────────────────────┘                          │  Secret (standard K8s)   │
                                                  │  (available to pods)     │
                                                  └──────────────────────────┘
```

---

## The Asymmetric Encryption Model

The RSA key pair means:

- **Encrypting** a secret requires only the public key — anyone can do it, even without cluster access
- **Decrypting** a `SealedSecret` requires the private key — only the cluster controller can do it

This is the correct model for GitOps: contributors can create new secrets without having read access to existing secret values, and the encrypted blob in Git is useless to an attacker without the private key.

`SealedSecret` objects are also **namespace-scoped**: a secret sealed for namespace `homeassistant` cannot be decrypted if moved to a different namespace. This prevents cross-namespace secret reuse.

---

## Example in This Repository

`kubernetes/applications/zigbee2mqtt/` contains a working `SealedSecret` that stores the MQTT broker password for Zigbee2MQTT:

```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: zigbee2mqtt-secrets
  namespace: homeassistant
spec:
  encryptedData:
    ZIGBEE2MQTT_CONFIG_MQTT_PASSWORD: <encrypted-blob>
```

The Sealed Secrets controller decrypts this and creates a standard `Secret` named `zigbee2mqtt-secrets` in the `homeassistant` namespace. The Zigbee2MQTT deployment reads `ZIGBEE2MQTT_CONFIG_MQTT_PASSWORD` from that secret.

---

## What Happens if the Cluster is Destroyed

If the cluster is wiped, the Sealed Secrets controller generates a **new** RSA key pair on startup. The old private key is gone, and all previously sealed secrets become permanently unreadable.

To recover, you must either:

1. **Re-seal all secrets** using the new cluster's public key, or
2. **Restore the key backup** (preferred)

### Back Up the Key

```bash
kubectl get secret -n sealed-secrets \
  -l sealedsecrets.bitnami.com/sealed-secrets-key \
  -o yaml > sealed-secrets-key-backup.yaml
```

Store this file in a secure location outside the repository (a password manager or encrypted backup). To restore after a cluster rebuild:

```bash
kubectl apply -f sealed-secrets-key-backup.yaml
kubectl rollout restart deployment sealed-secrets -n sealed-secrets
```

The controller will then be able to decrypt all existing `SealedSecret` objects in the repository.
