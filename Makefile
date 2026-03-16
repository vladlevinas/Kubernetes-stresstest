.PHONY: init plan apply destroy nodes token bench trivy goldilocks k6

KB = --kubeconfig=$(PWD)/kubeconfig.yaml

init:
	terraform init

plan:
	terraform plan

apply:
	terraform apply -auto-approve

destroy:
	terraform destroy -auto-approve

# ── Info ──────────────────────────────────────────────────────────────────────
nodes:
	kubectl get nodes -o wide $(KB)

pods:
	kubectl get pods -A $(KB)

# ── Chaos Mesh ────────────────────────────────────────────────────────────────
token:
	kubectl create token chaos-dashboard-admin -n chaos-mesh $(KB)

# ── kube-bench ────────────────────────────────────────────────────────────────
bench:
	kubectl logs job/kube-bench $(KB)

# ── Trivy ─────────────────────────────────────────────────────────────────────
trivy:
	kubectl get vulnerabilityreports -A -o wide $(KB)

# ── Goldilocks ────────────────────────────────────────────────────────────────
goldilocks:
	@echo "Open: http://\$$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type==\"ExternalIP\")].address}' $(KB)):32080"

# ── k6 ────────────────────────────────────────────────────────────────────────
k6:
	kubectl apply -f k6-test.yaml $(KB)
	kubectl get testrun -n k6 -w $(KB)
