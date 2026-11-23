# Kubernetes manifests

Kustomize layout: a shared **base**, plus the **eks overlay** that adds the
EKS-specific parts. Everything runs in the `ecommerce` namespace.

```
k8s/
├── base/                        the workloads (never applied on its own)
│   ├── kustomization.yaml       lists the resources below
│   ├── namespace.yaml           namespace "ecommerce"
│   ├── mongodb-users/           StatefulSet + headless Service + secret template
│   ├── mongodb-products/        StatefulSet + headless Service + secret template
│   ├── mongodb-orders/          StatefulSet + headless Service + secret template
│   ├── rabbitmq/                StatefulSet + ClusterIP & headless Services + secret template
│   ├── user-service/            Deployment + Service + ConfigMap + secret template
│   ├── product-service/         Deployment + Service + ConfigMap
│   ├── order-service/           Deployment + Service + ConfigMap
│   ├── notification-service/    Deployment + ConfigMap + secret template (no Service: nothing calls it)
│   ├── api-gateway/             Deployment + Service + ConfigMap
│   ├── storefront/              Deployment + Service
│   └── admin/                   Deployment + Service
└── overlays/
    └── eks/                     ECR images, ebs-gp3 StorageClass, ALB ingress, 2 replicas
```

## What the eks overlay changes

| | `base` | `overlays/eks` |
|---|---|---|
| Images | placeholder `shoplite/<name>` | `<account>.dkr.ecr…/dev/<name>:v1` |
| Storage | cluster default class | patched to `ebs-gp3` (+ the StorageClass) |
| Ingress | none | ALB (`ingressClassName: alb`) |
| Replicas (app Deployments) | 2 | 2 |
| Gateway health check | — | ALB annotation `/health` on the Service |

Put changes to the workloads themselves in `base/`, and EKS-specific settings
(a patch, `images:` or `replicas:`) in `overlays/eks/kustomization.yaml`.
Preview the final YAML before applying:

```bash
kubectl kustomize k8s/overlays/eks
```

## Secrets

Secrets are **not** part of the base or the overlays, so their values never
reach Git. Create them once per cluster from
the templates (the `secret.yaml` copies are git-ignored):

```bash
for d in mongodb-users mongodb-products mongodb-orders user-service rabbitmq notification-service; do
  cp k8s/base/$d/secret.yaml.example k8s/base/$d/secret.yaml   # then edit the values
done
kubectl create namespace ecommerce
for d in mongodb-users mongodb-products mongodb-orders user-service rabbitmq notification-service; do
  kubectl apply -f k8s/base/$d/secret.yaml
done
```

## Deploy to EKS

Full walkthrough from an empty AWS account:
[docs/EKS-DEPLOYMENT.md](../docs/EKS-DEPLOYMENT.md). In short, once the cluster
has the EBS CSI driver and the AWS Load Balancer Controller:

```bash
scripts/push-images.sh v1
# create the secrets (above), then:
kubectl apply -k k8s/overlays/eks
```

## Releasing a new version

1. Build and push the images with a new tag: `scripts/push-images.sh v2`.
2. Set `newTag: v2` in `k8s/overlays/eks/kustomization.yaml`.
3. Apply the overlay again (`kubectl apply -k k8s/overlays/eks`); the
   Deployments roll out the new images.

Always use a new tag: `imagePullPolicy: IfNotPresent` means reusing a tag does
not roll out new code.

