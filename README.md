# Azure DevSecOps — Complete Example (Options A, B, C)

## This archive contains three main deliverables:

* A) Full example repository files (CI pipeline, app, helm, infra skeleton) — ready to copy into your Git repo.
* B) GitOps (ArgoCD) configuration and workflow example — CI pushes image and updates GitOps repo to trigger ArgoCD for deploys.
* C) Production-ready Terraform module skeleton to provision hardened infra (VNet, private AKS, private ACR, Log Analytics, Key Vault, RBAC).

# Structure:
      - /app                     -> sample Node.js app + Dockerfile
      - /helm/myapp              -> Helm chart
      - /azure-pipelines-gitops.yml -> CI pipeline that builds image, scans, pushes image, updates GitOps repo
      - /gitops-config           -> example GitOps repo layout & ArgoCD Application manifests
      - /terraform/prod-module   -> production Terraform module (private AKS, private ACR, AAD integration placeholders)
      - /scripts                 -> helper scripts (update-helm-values.sh, argocd-install.sh)
      - README.md (this file)

# IMPORTANT:
      - Replace placeholders in files: <SUBSCRIPTION_ID>, <RESOURCE_GROUP>, <ACR_NAME>, <AKS_NAME>, <GITOPS_REPO_URL>, <AZURE_DEVOPS_SERVICE_CONN>, <TENANT_ID>, etc.
      - Some Azure AD / AAD integration steps require tenant administrator consent. These steps are marked and explained in the Terraform README.
      - Review and adapt network CIDRs, allowed IPs, and security rules to your corporate standards.

# Quick steps:

1. Create two Git repositories:

         - `app-repo` : push the `app/`, `helm/`, and pipeline yaml that builds images.
         - `gitops-repo` : push the `gitops-config/` folder (ArgoCD will watch this repo for manifests).

3. Provision infra:

           - Use `terraform/prod-module` with your values to create VNet, private AKS, private ACR, Log Analytics, Key Vault.
           - Alternatively, run from pipeline (recommended to validate infra immutably).
   
5. Set up Azure DevOps pipeline using `azure-pipelines-gitops.yml` (replace service connection name and secrets).
6. Install ArgoCD into the AKS cluster (script included) and connect it to `gitops-repo`.
7. Run CI (build + scan + push -> CI updates GitOps repo) -> ArgoCD syncs changes and deploys to cluster.

Files in this zip are examples and meant for learning and fast bootstrap. Review security, secrets handling,
networking, and organizational policies before production use.
