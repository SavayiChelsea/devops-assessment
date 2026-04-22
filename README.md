# devops-assessment

**Stack:** Node.js · Docker · Nginx · PostgreSQL · GitHub Actions · Terraform (AWS)

---

## Table of Contents

1. [How to Run Locally](#1-how-to-run-locally)
2. [CI/CD Pipeline Stages](#2-cicd-pipeline-stages)
3. [Architecture Diagram](#3-architecture-diagram)
4. [Assumptions and Improvements](#4-assumptions-and-improvements)

---

## 1. How to Run Locally

**Prerequisites:** Docker Desktop must be installed and running on your machine.

Clone the repository:

    git clone https://github.com/SavayiChelsea/devops-assessment.git
    cd devops-assessment

Create your local environment file:

    cp .env.example .env

Start everything with one command:

    docker-compose up --build

This starts three containers:

- **Nginx** — listens on port 80, forwards all traffic to the app
- **Node.js App** — runs the API on port 3000 (internal only)
- **PostgreSQL** — database on port 5432 (internal only)

Open a second terminal and test:

    curl http://localhost/
    curl http://localhost/health

Expected response from GET /:

    { "message": "API is running", "version": "1.0.0" }

Expected response from GET /health:

    { "status": "healthy", "timestamp": "2026-04-22T10:00:00.000Z", "database": "connected" }

If the database is unreachable, /health returns HTTP 503 with "database": "disconnected".

To stop all containers:

    docker-compose down

To stop and wipe all data:

    docker-compose down -v

Note: No credentials are hardcoded anywhere. All secrets load from the .env file at runtime.
The .env file is excluded from Git via .gitignore — only the safe template .env.example is committed.


---

## 2. CI/CD Pipeline Stages

**File:** `.github/workflows/pipeline.yml`  
**Platform:** GitHub Actions

### Stage 1 — Lint and Test
**Trigger:** Every pull request opened against main

Checks out the code, installs Node.js dependencies, and runs the linter and test suite.
Acts as a quality gate — a pull request cannot be merged if linting or tests fail.
Catches bugs and style issues before they ever reach the main branch.

### Stage 2 — Build and Push Docker Image
**Trigger:** Every push or merge into main

Builds the production Docker image using the multi-stage Dockerfile. Tags the image
with the Git commit SHA (e.g. sha-a1b2c3d) and as latest, then pushes both tags to
Docker Hub. Using the commit SHA means every image is fully traceable back to the
exact code that produced it. GitHub Actions layer caching speeds up repeat builds.

### Stage 3 — Manual Approval Gate
**Trigger:** After Stage 2 completes successfully

The pipeline pauses and waits for a designated reviewer to open GitHub Actions and
click Approve. Nothing reaches production without a human explicitly signing off.
Prevents accidental or automated deployments. Configured via GitHub repo Settings
then Environments then production then Required reviewers.

### Stage 4 — Deploy to Production
**Trigger:** After manual approval is granted

Deploys the exact commit SHA image to the production server. Using the SHA tag means
the version running in production is always known, reproducible, and auditable.

### Stage 5 — Rollback
**Trigger:** Manual only via GitHub Actions — Run workflow button

Re-deploys the last known stable image tag stored in the GitHub Secret
LAST_STABLE_IMAGE_TAG. Provides one-click recovery if a bad deployment reaches
production and needs to be immediately reversed without waiting for a new build.

### Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| DOCKERHUB_USERNAME | Your Docker Hub username |
| DOCKERHUB_TOKEN | Docker Hub access token |
| LAST_STABLE_IMAGE_TAG | Last known good image tag for rollback |

---

## 3. Architecture Diagram

### Local Environment (Docker Compose)
![Architecture Diagram](./architecture.png)
---

## 4. Assumptions and Improvements

### Assumptions Made

- **AWS** was chosen as the cloud provider. The same architecture can be reproduced
  on Azure using AKS, Azure Database for PostgreSQL, and Azure Key Vault.

- **Docker Compose is for local development only.** Production runs on EC2 with
  Docker as provisioned by Terraform, not via Compose.

- The application is **stateless.** All persistent data lives in PostgreSQL.
  Horizontal scaling is straightforward — add more EC2 instances behind an
  Application Load Balancer without any application changes.

- **No live cloud account is required.** Terraform is provided as reviewed code
  per the assessment instructions. Verify syntax locally with:

      cd terraform
      terraform init
      terraform validate

  Expected output: Success! The configuration is valid.

- GitHub Actions secrets must be added manually in repository Settings before
  the pipeline can push images or deploy to a server.

### One Thing I Would Improve With More Time

The most impactful improvement would be replacing the raw EC2 instance with
AWS ECS Fargate. The current EC2 approach requires manually managing the server —
patching the OS, handling Docker restarts, and scaling by hand. With Fargate,
AWS manages all of that automatically. Deployments become rolling updates with
zero downtime, scaling is based on CPU and memory metrics, and there is no server
to maintain or secure. The Terraform change is moderate in size but would
significantly improve the reliability and operational simplicity of the
production environment.
