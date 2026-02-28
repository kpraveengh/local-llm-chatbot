# Hello World React — Cloud Run CI/CD

A sample React (Vite) application deployed to **Google Cloud Run** via **GitHub Actions** CI/CD.

---

## Local Development

```bash
npm install
npm run dev        # http://localhost:3000
```

## Build & Preview Locally

```bash
npm run build
npm run preview    # http://localhost:3000
```

## Docker (local test)

```bash
docker build -t hello-world-react .
docker run -p 8080:8080 -e PORT=8080 hello-world-react
# Open http://localhost:8080
```

---

## Google Cloud Setup (One-Time)

### Prerequisites
- A GCP project with billing enabled
- `gcloud` CLI installed and authenticated
- A GitHub repository for this code

### Step 1 — Enable required APIs

```bash
export PROJECT_ID=<your-gcp-project-id>

gcloud config set project $PROJECT_ID

gcloud services enable \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  iamcredentials.googleapis.com \
  cloudresourcemanager.googleapis.com
```

### Step 2 — Create Artifact Registry repository

```bash
gcloud artifacts repositories create hello-world-react \
  --repository-format=docker \
  --location=us-central1 \
  --description="Docker images for hello-world-react"
```

### Step 3 — Set up Workload Identity Federation (keyless auth)

This lets GitHub Actions authenticate to GCP **without** a service account key.

```bash
# Create a service account
gcloud iam service-accounts create github-actions-sa \
  --display-name="GitHub Actions Service Account"

# Grant required roles
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-actions-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-actions-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-actions-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"

# Create Workload Identity Pool
gcloud iam workload-identity-pools create "github-pool" \
  --project=$PROJECT_ID \
  --location="global" \
  --display-name="GitHub Actions Pool"

# Create Workload Identity Provider
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --project=$PROJECT_ID \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# Allow the GitHub repo to impersonate the service account
# Replace <GITHUB_ORG> and <REPO_NAME> with your values
gcloud iam service-accounts add-iam-policy-binding \
  "github-actions-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --project=$PROJECT_ID \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')/locations/global/workloadIdentityPools/github-pool/attribute.repository/<GITHUB_ORG>/<REPO_NAME>"
```

### Step 4 — Get the WIF Provider resource name

```bash
gcloud iam workload-identity-pools providers describe "github-provider" \
  --project=$PROJECT_ID \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --format="value(name)"
```

This returns something like:
```
projects/<PROJECT_NUMBER>/locations/global/workloadIdentityPools/github-pool/providers/github-provider
```

### Step 5 — Add GitHub Secrets

In your GitHub repo, go to **Settings → Secrets and variables → Actions** and add:

| Secret Name             | Value                                                                                   |
|-------------------------|-----------------------------------------------------------------------------------------|
| `GCP_PROJECT_ID`        | Your GCP project ID (e.g. `my-project-123`)                                            |
| `WIF_PROVIDER`          | Full provider resource name from Step 4                                                 |
| `WIF_SERVICE_ACCOUNT`   | `github-actions-sa@<PROJECT_ID>.iam.gserviceaccount.com`                                |

---

## CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/deploy.yml`) runs automatically:

| Trigger                  | Action                                     |
|--------------------------|--------------------------------------------|
| Push to `main`           | Build → Test → Docker Build → Deploy       |
| Pull Request to `main`   | Build → Test (no deploy)                   |

### Pipeline Flow

```
Push to main
  ↓
Build & Test (Node.js)
  ↓
Build Docker Image
  ↓
Push to Artifact Registry
  ↓
Deploy to Cloud Run
  ↓
Public URL available ✓
```

---

## Project Structure

```
.
├── .github/workflows/deploy.yml   # CI/CD pipeline
├── src/
│   ├── App.jsx                    # Main React component
│   ├── App.css                    # App styles
│   ├── main.jsx                   # Entry point
│   ├── index.css                  # Global styles
│   └── assets/react.svg           # React logo
├── public/vite.svg                # Vite logo
├── index.html                     # HTML template
├── vite.config.js                 # Vite configuration
├── Dockerfile                     # Multi-stage Docker build
├── nginx.conf                     # Nginx configuration
├── .dockerignore                  # Docker ignore rules
├── .gitignore                     # Git ignore rules
├── package.json                   # Dependencies & scripts
└── README.md                      # This file
```

---

## Modifying the Deployment

- **Region:** Change `REGION` in the workflow env
- **Resources:** Adjust `--memory`, `--cpu`, `--max-instances` in the deploy step
- **Custom domain:** Use `gcloud run domain-mappings create` after deployment
