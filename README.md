# DO Kubernetes Testing Stack

DigitalOcean DOKS + Chaos Mesh + k6 + Trivy + kube-bench + Goldilocks — deployed in one pass.

## Stack

| Tool | Purpose | Access |
|------|---------|--------|
| Chaos Mesh | Fault injection | `http://<NODE-IP>:32333` |
| k6 Operator | Load testing | CLI / kubectl |
| Trivy Operator | Image vulnerability scan | kubectl |
| kube-bench | CIS security audit | kubectl logs |
| Goldilocks | Resource requests advisor | `http://<NODE-IP>:32080` |

**Cost:** ~$24/mo (2x `s-1vcpu-2gb` nodes, Frankfurt)

## Prerequisites

```bash
terraform >= 1.3
doctl
kubectl
```

## Quick Start

```bash
# 1. Get latest k8s version slug
doctl kubernetes options versions

# 2. Configure
cp terraform.tfvars.example terraform.tfvars
# fill in: do_token, k8s_version

# 3. Deploy (~10 min)
make init
make apply

# 4. Get node IPs
make nodes
```

## Usage

```bash
# Chaos Mesh — get dashboard token
make token
# open http://<NODE-IP>:32333

# kube-bench — CIS audit results
make bench

# Trivy — vulnerability reports
make trivy

# Goldilocks — resource recommendations
# open http://<NODE-IP>:32080

# k6 — run load test (edit k6-test.yaml first)
make k6
```

## Run from GitHub

### Option 1 — Clone and run locally

```bash
git clone https://github.com/vladlevinas/Kubernetes-stresstest
cd /Kubernetes-stresstest
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # fill in do_token + k8s_version
make init && make apply
```

### Option 2 — GitHub Actions (one-click deploy)

Add `.github/workflows/deploy.yml` to your repo:

```yaml
name: Deploy K8s Stack

on:
  workflow_dispatch:
    inputs:
      action:
        description: 'apply or destroy'
        required: true
        default: 'apply'

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.7.0
      - name: Terraform run
        run: |
          terraform init
          terraform ${{ github.event.inputs.action }} -auto-approve
        working-directory: do-k8s-full
        env:
          TF_VAR_do_token: ${{ secrets.DO_TOKEN }}
          TF_VAR_k8s_version: "1.31.1-do.4"
```

Add secret in GitHub: `Settings → Secrets → Actions → DO_TOKEN`

Run: `Actions → Deploy K8s Stack → Run workflow → apply`

## Destroy

```bash
make destroy
```

> Don't forget to destroy when not in use — nodes keep billing.
