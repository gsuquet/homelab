# Roll back kagent and agentgateway

This guide removes kagent and agentgateway from `kind-local`, and stops the access of the cluster to Vertex AI. The rollout is in [Roll out kagent and agentgateway](roll-out-kagent-and-agentgateway.md). The objects are in [kagent and agentgateway (reference)](../reference/kagent-and-agentgateway.md).

## The fast rollback on `kind-local`

1. Run `mise run instance:down`.
2. Check out the commit before the change.
3. Run `mise run instance:up`.

## The rollback in Git

The order matters, because the controllers must remove their finalizers and their run-time objects.

1. While the controllers still run, remove the `Agent`, `ModelConfig`, `Gateway`, `HTTPRoute` and `AgentgatewayBackend` objects from the templates.
2. Sync. The controllers delete the agent Deployments and the proxy Deployment.
3. Remove `kagent` from `cluster.yaml`, then `agentgateway`. The `Application` template has no resources finalizer, thus Argo CD keeps the objects.
4. Delete the namespaces `kagent` and `agentgateway-system`.
5. If an object stays in `Terminating`, remove its finalizer by hand.
6. Delete the cluster-scoped objects by hand. Select them with the label `app.kubernetes.io/instance`:
   - the agentgateway `ClusterRole` and `ClusterRoleBinding` objects,
   - the kagent-tools `ClusterRole`,
   - the kagent metrics `ClusterRole`.
7. Delete the `GatewayClass` `agentgateway`. The controller made it at run time.
8. Delete the CRDs `*.kagent.dev` and `*.agentgateway.dev`.
9. In `accounts/gcp/`, remove the binding of the proxy subject, or disable `agentgateway-vertex`.
10. Apply `accounts/gcp/` in one apply session. Then no token of `kind-local` reaches Vertex AI.

## If agentgateway fails but kagent works

Do not send the model calls directly from kagent to Gemini. With no API key, a direct path needs the kagent provider `GeminiVertexAI` and a Google identity in `kagent`. The invariant of `kagent` forbids it. M1 waits for the fix of agentgateway.
