# Handover: development → DevOps

| | |
|---|---|
| Project | ShopLite e-commerce microservices |
| Handover date | 2026-10-06 |
| Code baseline | `main` branch, see git log for the exact commit |
| Development contact | _name / email / Slack_ |
| DevOps owner | _to be assigned_ |

This document covers what is delivered, what is still missing, and what the
DevOps team needs to decide before production. Read it before the other docs.

## Delivered

| Area | State |
|---|---|
| Application | Feature complete: signup and login, product catalogue, cart, checkout, order history and cancellation, admin product management, admin order fulfilment, email notifications |
| Containers | Dockerfiles for all 7 deployables; each has a `HEALTHCHECK` |
| Local environment | `docker-compose.yml` runs the full stack (11 containers, health-gated startup). Verified end to end. |
| Health checks | gRPC `grpc.health.v1` (readiness and liveness) on the gRPC services; HTTP health endpoints on the rest ([SERVICES.md](SERVICES.md)) |
| Resilience | Graceful SIGTERM shutdown, exit code 1 on startup failure, RabbitMQ auto-reconnect, dead-letter queue for failed notifications |
| Kubernetes | Manifests for every service: namespace, StorageClass, mongodb-users, mongodb-products, mongodb-orders, rabbitmq, user-service, product-service, order-service, notification-service, api-gateway, storefront, admin, and the ALB Ingress |
| Tooling | `scripts/push-images.sh` (amd64 build and ECR push), `scripts/smoke-test.sh` (post-deploy checks) |

**Tested so far:**
- The whole application on docker-compose: functional flows, oversell
  prevention under concurrent orders, dead-letter handling, RabbitMQ
  reconnect, MongoDB outage and recovery.
- The core Kubernetes workloads on a local Kubernetes cluster.

**Not yet tested on EKS.** The ALB Ingress and gp3 StorageClass have never
been applied to a real cluster.

## Outstanding work

| # | Item | Notes |
|---|---|---|
| 1 | ~~K8s manifests: order-service, notification-service, mongodb-orders~~ | **Done.** |
| 2 | ~~Remove `--platform=linux/arm64` from the order-service and notification-service Dockerfiles~~ | **Done**, and both are in `scripts/push-images.sh`. |
| 3 | **CI/CD pipeline** | None exists. Suggested: build and push on merge to `main`, tagged with the git SHA; deploy; run `smoke-test.sh`. |
| 4 | **TLS** | The Ingress serves HTTP only. Add an ACM certificate (`alb.ingress.kubernetes.io/certificate-arn`) and an HTTP→HTTPS redirect. |
| 5 | **DNS** | Route 53 alias record from the domain to the ALB. |
| 6 | **SMTP provider** | notification-service is set up for Amazon SES (`email-smtp.us-east-1.amazonaws.com:587` in `notification-service/configmap.yaml`). Verify a sender domain in SES, create SMTP credentials, and put them in `notification-service-secret`. Until then, orders work but emails fail and land in the DLQ. |
| 7 | **Backups** | No MongoDB backups. Suggested: AWS Backup or EBS snapshots of the `data-mongodb-*` PVCs. Manual procedure is in the [RUNBOOK](RUNBOOK.md#back-up-and-restore-mongodb). |
| 8 | **Observability** | Logs are plain text on stdout; there are no metrics or tracing. Suggested: Container Insights or Fluent Bit for logs, Prometheus/Grafana or CloudWatch for metrics, and alerts on pod restarts, 5xx rate, DLQ depth and PVC usage. |

## Decisions needed from DevOps

| Decision | Current state / developer recommendation |
|---|---|
| Secrets management | Git-ignored `secret.yaml` files applied by hand. Recommend AWS Secrets Manager with the External Secrets Operator. |
| Managed data stores | MongoDB and RabbitMQ run in-cluster as single replicas. For production, consider MongoDB Atlas or DocumentDB (check compatibility) and Amazon MQ for RabbitMQ. |
| Image tagging policy | Manifests use `:v1`. Recommend immutable tags (git SHA) and enabling ECR tag immutability. |
| Environments | Only one set of manifests, hard-coded to account `395947696643` / `us-east-1`. Multiple environments (dev/stage/prod) need overlays (Kustomize or Helm) or a separate folder per environment. |
| Autoscaling | None. HPA needs metrics-server; the CPU requests in the manifests are a starting point. |
| Network policies | None. Recommend default-deny in `ecommerce`, then allow only the documented traffic paths ([ARCHITECTURE.md](ARCHITECTURE.md)). |

## Risks

| Risk | Impact | Recommendation |
|---|---|---|
| **Node.js 20 is end-of-life (April 2026)** | No security patches for the runtime in any backend image | Upgrade the service images to `node:22-alpine` (LTS) and re-test |
| **`JWT_SECRET` falls back to a public default** (`supersecretkey`) if unset | Anyone could create admin tokens | Always set it; it's provided by `k8s/base/user-service/secret.yaml`. Development is asked to change the service to refuse to start without it. |
| Old JWT secret is in git history | Same as above, for any environment that ever used it | Never use `supersecretkey` anywhere; rotate it if it was ever deployed |
| No rate limiting on `/api` (login and register are internet-facing) | Brute-force and abuse | AWS WAF on the ALB (rate-based rules), or limits in the gateway |
| Containers run as root (no `securityContext`) | Bigger blast radius if a container is compromised | Reintroduce `runAsNonRoot` and read-only root filesystems once validated; this was removed deliberately for now |
| Single-replica MongoDB and RabbitMQ | A node failure means downtime until the pod is rescheduled. EBS volumes are tied to one AZ, so the pod can only reschedule within that AZ. | Managed services, or replica sets (see decisions) |
| No PodDisruptionBudgets, no `preStop` delay | Node drains can evict all replicas of a service at once; a few 502s during rollouts | Add PDBs (`minAvailable: 1`) and a short `preStop` sleep before production traffic |
| gRPC connections are long-lived | Extra replicas of user-service and product-service get little traffic | Headless Services with client-side `round_robin`, or a service mesh |
| Order events are published without an outbox | A RabbitMQ outage at publish time means a missed email (orders and stock stay correct) | Acceptable for now; implement a transactional outbox if emails become critical |
| No automated tests | Regressions are only caught by the smoke test | Development to add unit and integration tests to CI |

## Production readiness checklist

- [ ] Outstanding items 1–2 done; full stack running on EKS
- [ ] `scripts/smoke-test.sh https://<domain>` passes, including orders
- [ ] TLS and DNS configured
- [ ] Secrets in a secret manager; no `secret.yaml` on laptops
- [ ] Strong unique `JWT_SECRET` and MongoDB/RabbitMQ passwords per environment
- [ ] Backups enabled and a restore tested
- [ ] Logs centralised; alerts for restarts, 5xx, DLQ depth, disk usage
- [ ] Node.js upgraded to 22 LTS
- [ ] Rate limiting / WAF on the ALB
- [ ] CI/CD pipeline with immutable image tags
- [ ] Load test done; resource requests and limits and replica counts tuned
- [ ] PDBs and `preStop` delay re-added
- [ ] First admin user promoted ([RUNBOOK](RUNBOOK.md#promote-a-user-to-admin))
