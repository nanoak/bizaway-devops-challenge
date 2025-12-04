# ☁️ BizAway – DevOps Challenge

This repository contains my solution for the BizAway DevOps challenge.  
It covers containerization, database initialization, local orchestration, CI/CD, security, infrastructure as code, Kubernetes manifests and monitoring.

The original challenge description is available in this README for reference.  
All design decisions and detailed explanations are documented in `CHALLENGE_REPORT.md`.

---

## 📁 Repository Structure

```text
.
├── .github/workflows/          # GitHub Actions CI pipeline (tests + image build + smoke test)
├── 01 Dockerfile/              # Multi-stage Dockerfile for the NestJS application
├── 02 MongoDB/                 # Local Docker Compose for API + MongoDB + DB initialization
├── 03 Local Orchestration
├── 04 Automation (CI-CD)
├── 05 Security Fundamentals
├── 06 Infrastructure as Code (IaC)/
│   └── terraform/              # Terraform modules and environments for EKS on AWS
├── 07 Kubernetes Deployment/
│   └── base/                   # Kubernetes manifests (namespace, app, MongoDB, ingress, etc.)
├── 09 Challenge Report/        # Supporting files related to the report
├── main/                       # Original NestJS application (source code)
├── CHALLENGE_REPORT.md         # Main technical report with all design choices
└── README.md                   # This file
```

---

## 🚀 How to Run Locally (Docker Compose)

From the repository root:

```bash
cd "02 MongoDB"
docker compose up --build
```

This will:

- Start a MongoDB container
- Run the initialization script (`main/init_scripts/mongo-init.js`)
- Build and start the BizAway API container
- Expose the API on `http://localhost:3000`

To reset the database:

```bash
docker compose down --volumes
```

---

## 🔁 CI/CD (GitHub Actions)

The CI pipeline is defined in:

```text
.github/workflows/CI.yaml
```

Pipeline stages:

1. **test**
   - Install dependencies using `pnpm`
   - Run the unit tests with Jest

2. **docker-build**
   - Build the production Docker image using `01 Dockerfile/Dockerfile`
   - Tag the image with the short commit SHA
   - Save the image as a tarball and upload it as an artifact

3. **smoke-test**
   - Download the image artifact
   - Load the image into Docker
   - Run a lightweight smoke test to ensure the container can start and execute a simple Node.js command

This guarantees that every change is validated both at the **code level** (tests) and at the **container runtime level** (smoke test).

---

## 🛡️ Security & Best Practices

Key security-related decisions (explained in detail in `CHALLENGE_REPORT.md`):

- Containers run as a **non-root user** (`bizuser`) in the final image.
- Multi-stage Docker build with a **minimal runtime image**:
  - Only `dist/` and production dependencies are included.
  - No build tools or source code in the final image.
- Secrets (e.g. `MONGODB_URI`) are provided via **environment variables** and Kubernetes **Secrets**.
- MongoDB is never exposed publicly in Kubernetes; it is only reachable from the API pods through an internal Service.

---

## ☸️ Kubernetes & IaC

Infrastructure is described using **Terraform** (EKS on AWS):

- VPC, subnets and networking
- EKS cluster
- Managed node groups

Kubernetes manifests (in `07 Kubernetes Deployment/base/`) include:

- Namespace
- Deployments and Services for the API
- StatefulSet and Service for MongoDB
- ConfigMaps and Secrets
- Ingress configuration (ALB on EKS)
- Resource requests/limits and readiness/liveness probes

---

## 📊 Monitoring

The monitoring design (described in Section 8 of `CHALLENGE_REPORT.md`) is based on:

- **Prometheus** for metrics scraping (application + Kubernetes)
- **Grafana** for dashboards
- Application-level metrics (request rate, latency, error rate)
- Container-level metrics (CPU, memory, restarts)

An example dashboard layout is included in the report.

---

## 📄 Challenge Description (for reference)

This challenge is divided into Required Tasks (essential for production readiness) and Advanced Tasks (to showcase deeper expertise).
We will evaluate the quality, clarity, and security of your solution.
Feel free to modify the application code if it supports your DevOps goals (e.g., adding metrics endpoints).

Application sources can be found in the challenge repository.

### 1. Containerization

Create an efficient Dockerfile for the NestJS application.  
Focus on multi-stage builds and best practices for small, secure images.

---

### 2. Database Initialization

A database initialization file (e.g., `init-mongo.js`) is present in the repository.  
Integrate a mechanism (e.g., a dedicated init container, script, or Docker entrypoint) to automatically load this file and prepare the MongoDB schema before the main application starts.

---

### 3. Local Orchestration

Create a Docker Compose setup for local development and demonstration.  
The setup must include:

- The NestJS application container
- A MongoDB container
- The database initialization step (Task 2)

---

### 4. Automation (CI/CD)

Implement a basic CI/CD pipeline (using GitHub Actions, GitLab CI, etc.).  
The pipeline must, at minimum:

- Build and
- Test the application image successfully.

---

### 5. Security Fundamentals

Implement solutions to secure the application environment, including (but not limited to):

- Managing secrets (e.g., in Docker Compose)
- Ensuring secure container configuration (non-root users, least privileges)

---

### 6. Infrastructure as Code (IaC)

Create Terraform files to provision the necessary cloud infrastructure to deploy the Kubernetes cluster (e.g., networking, compute resources).  
Choose any major cloud provider (AWS, GCP, Azure).

---

### 7. Kubernetes Manifests

Create comprehensive Kubernetes manifest files (`Deployments`, `Services`, `ConfigMaps`, `Secrets`, etc.) for the application and its database (if self-hosted).  
Apply Kubernetes best practices, including:

- Resource Limits/Requests  
- Readiness/Liveness Probes

---

### 8. Monitoring

Implement a Monitoring Solution (e.g., integrating Prometheus/Grafana/ELK + APM) to track key application metrics such as:

- Request latency
- Error rates
- Container health

Include an example dashboard setup or configuration.

---

### 9. Documentation

Document all design choices (why you chose a specific base image, how you handled initialization, security choices, cloud infrastructure, etc.) in a detailed `CHALLENGE_REPORT.md`.
