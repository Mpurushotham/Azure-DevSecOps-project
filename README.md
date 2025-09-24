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

#  Option -A Step-by-step actions

## 0) Basic prerequisites (local)
	•	Install Azure CLI (az), Docker, Git.
	•	Sign in to Azure locally:
```bash
az login
az account show
```

## 1) Create a resource group + ACR (Azure CLI)

Create a resource group (pick region close to you, e.g. westeurope):

```bash
export RG=my-devsecops-rg
export LOCATION=westeurope
az group create -n $RG -l $LOCATION
```
Create an Azure Container Registry (Basic/Standard for cost savings). Replace <acrname> with a globally unique lowercase name (5–50 chars).  ￼

```bash
export ACR_NAME=<youracrname>    # e.g. acmemyappacr
az acr create --name $ACR_NAME --resource-group $RG --sku Basic --location $LOCATION
az acr show --name $ACR_NAME --resource-group $RG --query "loginServer" -o tsv
```

2) Create a Service Principal for GitHub Actions (for CI to call Azure)

Create an SP scoped to the resource group (least privilege for experiments). The --sdk-auth output is the JSON you will store in GitHub as AZURE_CREDENTIALS.
This JSON format is exactly what azure/login expects. 

```bash
az ad sp create-for-rbac \
  --name "sp-github-actions-$RANDOM" \
  --role "Contributor" \
  --scopes /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RG \
  --sdk-auth
```
Save the JSON printed by that command — you will paste it into a GitHub secret called AZURE_CREDENTIALS.

## 3) (Optional for quick ACI pull) Enable ACR admin user temporarily

To allow ACI to pull from your private ACR easily for a test, enable ACR admin user (temporary — turn off when done).

```bash
az acr update -n $ACR_NAME -g $RG --admin-enabled true
az acr credential show -n $ACR_NAME -g $RG
# note username and passwords[0].value
```
Store username/password as GitHub secrets ACR_ADMIN_USERNAME and ACR_ADMIN_PASSWORD (or you can query them from the CI job when running az).

Security note: enabling admin user is not recommended in production — use managed identities / role assignments instead. Use it only for quick tests and turn it off after:
```bash
az acr update -n $ACR_NAME -g $RG --admin-enabled false
```
## 4) Create a GitHub repo & add the example app
	•	Create a new repository in GitHub (e.g. azure-devsecops-demo).
	•	Copy the app/, Dockerfile, and helm/ (if you want) from the example bundle I prepared earlier (or create your own minimal Node app). (I provided a ZIP earlier you can download.)

## 5) Add secrets in GitHub repo (Settings → Secrets & variables → Actions)
	•	AZURE_CREDENTIALS ← the SP JSON from step 2
	•	ACR_NAME ← your registry name
	•	ACR_LOGIN_SERVER ← result from az acr show (e.g. myacr.azurecr.io)
	•	RESOURCE_GROUP ← $RG
	•	If using ACR admin user for ACI: ACR_ADMIN_USERNAME, ACR_ADMIN_PASSWORD.

for example see the screenshot : 

<img width="1081" height="862" alt="Screenshot 2025-09-24 at 23 13 03" src="https://github.com/user-attachments/assets/0149f5b0-1357-4e13-abe0-cac26cb3ffcb" />

## 6) Add this GitHub Actions workflow (.github/workflows/ci-aci.yml)

      Copy this into your repo (adjust environment names and secrets). This workflow:
      	1.	logs into Azure using azure/login (need AZURE_CREDENTIALS),
      	2.	builds Docker, pushes to ACR,
      	3.	runs Trivy container scan,
      	4.	deploys to ACI using az container create and ACR credentials (from az acr credential show).
```YAML
name: CI → Build → Scan → ACR → Deploy to ACI
on:
  push:
    branches: [ main ]

env:
  IMAGE_NAME: myapp

jobs:
  build-deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4

    - name: Azure login
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}

    - name: Build Docker image
      run: |
        ACR=${{ secrets.ACR_LOGIN_SERVER }}
        docker build -t $ACR/${{ env.IMAGE_NAME }}:${{ github.run_id }} ./app

    - name: Login to ACR (for docker push)
      run: |
        az acr login --name ${{ secrets.ACR_NAME }}

    - name: Push image to ACR
      run: |
        ACR=${{ secrets.ACR_LOGIN_SERVER }}
        docker push $ACR/${{ env.IMAGE_NAME }}:${{ github.run_id }}

    - name: Run Trivy image scan (report)
      run: |
        ACR=${{ secrets.ACR_LOGIN_SERVER }}
        docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image --exit-code 1 --severity CRITICAL,HIGH $ACR/${{ env.IMAGE_NAME }}:${{ github.run_id }} || true

    - name: Get ACR admin creds and Deploy to ACI (quick test)
      run: |
        # (we enabled ACR admin earlier for quick pull; otherwise use secured method)
        ACR_NAME=${{ secrets.ACR_NAME }}
        RG=${{ secrets.RESOURCE_GROUP }}
        CREDS=$(az acr credential show -n $ACR_NAME -g $RG)
        USERNAME=$(echo "$CREDS" | jq -r .username)
        PASSWORD=$(echo "$CREDS" | jq -r .passwords[0].value)
        ACR_LOGIN=${{ secrets.ACR_LOGIN_SERVER }}
        IMAGE=$ACR_LOGIN/${{ env.IMAGE_NAME }}:${{ github.run_id }}

        az container create -g $RG -n myapp-${{ github.run_id }} \
          --image $IMAGE \
          --cpu 1 --memory 1 \
          --registry-login-server $ACR_LOGIN \
          --registry-username $USERNAME \
          --registry-password $PASSWORD \
          --dns-name-label myapp-${{ github.run_id }} --os-type Linux --ports 80
```
 >[!NOTE]
>References: GitHub + Azure login usage + secret format for AZURE_CREDENTIALS are documented by Microsoft and the azure/login action.  ￼
>Deploying an instance into Azure Container Instances is shown in the ACI quickstart docs.  ￼

## 7) Run the pipeline & test
	•	Push to main.
	•	After GitHub Actions completes, the step az container show (or your ACI DNS) will expose a URL like http://<dns-name>.<region>.azurecontainer.io. Open it to validate.

## 8) Clean up (to avoid charges)

      Remove the resource group when finished AND If you enabled ACR admin, turn it off:
```bash
az group delete --name $RG --yes --no-wait
az acr update -n $ACR_NAME -g $RG --admin-enabled false
```

## Final Result: 
      GitOps Actions ACR ACI deployed 
      
<img width="1392" height="650" alt="Screenshot 2025-09-24 at 23 26 58" src="https://github.com/user-attachments/assets/021b909a-d5bd-4d0d-b94f-5d5106934667" />

      AKS+ ArgoCD 

<img width="1828" height="614" alt="Screenshot 2025-09-24 at 23 27 50" src="https://github.com/user-attachments/assets/5480fd29-8bae-4f3e-8076-f7420761988d" />

# OPTION - B GitOps path (AKS + ArgoCD) — step-by-step (once Quick path works)

When to move to this: after you’ve validated builds/pushes with the quick flow and you’re comfortable creating a small AKS cluster (this uses more credits). ArgoCD installs into AKS and watches a Git repo for Helm manifests. See ArgoCD getting started / install docs.  ￼

reference deployed repo i.e https://github.com/Mpurushotham/myapp-gitops

## 1) Provision AKS (small single-node cluster for testing)

      Warning: AKS nodes are chargeable. Use a single small node (Standard_B2s / Standard_DS2_v2) while testing.
```bash
# example (replace names)
az aks create -g $RG -n myaks --node-count 1 --node-vm-size Standard_B2s --generate-ssh-keys --attach-acr $ACR_NAME
az aks get-credentials -g $RG -n myaks
kubectl get nodes
```
      --attach-acr grants AKS permission to pull from ACR (role assignment) — easier than secrets.
## 2) Install ArgoCD into AKS

      Follow the ArgoCD install quickstart (kubectl apply the official manifest).
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```
Expose ArgoCD UI (port-forward or use an ingress / LoadBalancer) and login via the CLI or UI.

## 3) Create a small GitOps repo

      Repository layout (example):
```
  gitops-repo/
  helm/myapp/values.yaml   # image.repository + image.tag
  helm/myapp/Chart.yaml
  argocd/myapp-application.yaml  # ArgoCD Application manifest (points to helm/myapp)
```
Create the ArgoCD Application so ArgoCD knows to sync helm/myapp to prod namespace.

## 4) GitHub Actions pipeline → update GitOps repo

      Your CI workflow (GitHub Actions) does:
            	1.	Build & push image to ACR (same as quick path).
            	2.	Clone gitops-repo (via a GitHub token secret GITOPS_TOKEN), update helm/myapp/values.yaml to the new tag, commit & push.
            	3.	ArgoCD will detect the change and sync (if auto-sync enabled) or you click Sync in the UI.

Create GITOPS_TOKEN: a GitHub personal access token (repo write) stored as a secret in the app repo (GITOPS_TOKEN) so CI can push to your GitOps repo.

Example snippet for the update step inside Actions (after push to ACR):
```bash
# simple sed-based update (safe if format stable)
git clone https://$GITOPS_TOKEN@github.com/<org>/gitops-repo.git gitops
cd gitops
sed -i "s/^  tag: .*/  tag: ${TAG}/" helm/myapp/values.yaml
git add helm/myapp/values.yaml
git commit -m "ci: image ${TAG}"
git push origin main
```
>[!NOTE] for robust YAML edits use yq to preserve formatting.
>References: ArgoCD get started & app creation.

# Additional tooling (SAST / SCA)
	•	Trivy (SCA) — we used the containerized Trivy run inside the Actions job. (aquasecurity/trivy)
	•	SonarCloud / SonarQube (SAST) — add Sonar scanner steps in the workflow; SonarCloud provides GitHub Action integrations.

Helpful references for adding these integrations are in the example pipeline I gave earlier and the SonarCloud GH Action docs (if you want, I’ll paste the SonarCloud GitHub Action snippet).

⸻

# Cost & safety checklist (very important)
	•	Use Basic ACR, ACI for dev/testing, and a single-node AKS if testing GitOps. Monitor costs in Azure portal. Azure free account provides $200 credit for 30 days — check your remaining credit in the portal.  ￼
	•	Don’t leave clusters/images running: delete resource groups when done.
	•	Turn off ACR admin after testing.
	•	Use service principals and GitHub secrets rather than embedding credentials.

⸻

# Quick reference links (official docs I used)
	•	Authenticate GitHub Actions to Azure (how to create service principal + JSON AZURE_CREDENTIALS).  ￼
	•	Create an Azure Container Registry (az acr create).  ￼
	•	Deploy container to Azure Container Instances (az container create quickstart).  ￼
	•	ArgoCD getting started / installation.  ￼
      
