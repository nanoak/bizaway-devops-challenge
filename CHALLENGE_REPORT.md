
---
# 1. Containerization

This section describes the containerization strategy used for the NestJS application, focusing on multi-stage builds and best practices for building **small** and **secure** container images.

## 1.1 Base Image Selection

The base image chosen is:

```dockerfile
node:24-alpine
```

Reasons for this choice:

- Official Node.js image maintained by the Node.js project.
- Alpine Linux base significantly reduces image size.
- Smaller base → smaller final image and reduced attack surface.
- Up-to-date Node.js runtime for long-term maintainability.

## 1.2 Multi-Stage Build Architecture

The Dockerfile uses a 4-stage multi-stage build:

```text
+------------+     +------------+     +------------+     +------------+
|   base     | --> |    deps    | --> |  builder   | --> |   final    |
+------------+     +------------+     +------------+     +------------+
      |                  |                  |                 |
      |                  |-- pnpm install   |                 |
      |                                     |-- build app      |
      |                                                       |
      |----------------------------------------------> runtime
```

Benefits of this architecture:

- Clear separation of concerns.
- Reusable layers and faster rebuilds.
- Minimal, clean runtime image.
- Secure production container.

## 1.3 Detailed Stage Breakdown
### 1.3.1 Base Stage

Responsibilities:

- Defines the working directory: /srv/app/main.
- Enables Corepack for pnpm support.
- Provides a consistent base for all following stages.

```dockerfile
FROM node:24-alpine AS base
WORKDIR /srv/app/main
RUN corepack enable
```

### 1.3.2 Dependencies Stage

**Responsibilities:**

- Installs all Node.js dependencies (including devDependencies).
- Optimizes Docker layer caching.

Key decisions:

- Only dependency files are copied before installation.
- `--frozen-lockfile` enforces deterministic builds.

```dockerfile
FROM base AS deps
COPY main/package.json main/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile
```

Docker Layer Caching Flow:

```text
┌────────────────────────────┐
│ Change in source code?     │ -> ✅ reuse deps layer
│ Change in dependencies?    │ -> ❌ rebuild deps layer
└────────────────────────────┘
```

### 1.3.3 Builder Stage

**Responsibilities:**

- Compiles TypeScript → JavaScript.
- Produces the dist/ build artifact.

```dockerfile
FROM base AS builder
COPY --from=deps /srv/app/main/node_modules ./node_modules
COPY main ./
RUN pnpm run build
```

Output:

```text
/srv/app/main/dist/
├── main.js
├── app.module.js
└── ...
```

### 1.3.4 Final Runtime Stage

**Responsibilities:**

- Produces the minimal runtime image.
- Copies only required runtime artifacts.

```dockerfile
FROM node:24-alpine AS final
WORKDIR /srv/app/main
ENV NODE_ENV=production

RUN corepack enable

RUN addgroup -g 1001 bizgroup \
  && adduser -D -u 1001 -G bizgroup bizuser

COPY main/package.json ./package.json
COPY --from=builder /srv/app/main/dist ./dist
COPY --from=builder /srv/app/main/node_modules ./node_modules

RUN pnpm prune --prod \
    && chown -R bizuser:bizgroup /srv/app

USER bizuser
EXPOSE 3000
CMD ["node", "dist/main.js"]
```

## 1.4 Container Security Design

Security measures implemented:

| Measure             | Description                                        |
|---------------------|----------------------------------------------------|
| Non-root user       | Container runs as `bizuser` instead of root       |
| Minimal runtime     | No source code or development tools               |
| Pruned dependencies | Only production dependencies are included         |
| Small base image    | Alpine reduces attack surface                     |
| Immutable runtime   | No build tools present in the final runtime image |

## 1.5 Image Size & Optimization

Image size optimizations:

- Alpine-based Node image.
- Multi-stage builds.
- Removal of development dependencies.
- Avoidance of unnecessary artifacts (src, test, .git, etc.).

This approach significantly reduces the final image size compared to a single-stage build.

## 1.6 Build Reproducibility

Build reproducibility is achieved through:

- Lockfile-based dependency installation.
- `--frozen-lockfile` enforcement.
- Controlled multi-stage build pipeline.
- Explicit runtime environment configuration (NODE_ENV=production).

## 1.7 Container Build Flow Diagram

```text
            Source Code (Host)
                    |
                    v
   +--------------------------------+
   |          Docker Build          |
   +--------------------------------+
        |           |           |
        v           v           v
     base        deps        builder
                                 |
                                 v
                               final
                                 |
                                 v
                        Runtime Container Image
```

## 1.8 Build & Run Instructions
Build

```bash
docker build -f "01 Dockerfile/Dockerfile" -t bizaway/bizawayapi .
```

Run

```bash
docker run --rm -p 3000:3000 --name BizAwayAPI bizaway/bizawayapi
```

<br><br><br>

---

# 2. Database Initialization

This section describes how the MongoDB database is automatically initialized before the NestJS application starts, fulfilling the requirement to prepare the schema and seed data as part of the environment startup.

## 2.1 Initialization Script

The repository includes a MongoDB initialization script:

```text
main/init_scripts/mongo-init.js
```

The script is responsible for:

- Selecting the same database used by the NestJS application (`tech_challenge`).
- Creating the `visits` collection.
- Inserting a small set of sample visit documents.

```js
db = db.getSiblingDB('tech_challenge');

db.createCollection('visits');

db.visits.insertMany([
  {
    visit_dt: new Date(),
    ip: '127.0.0.1',
    user_agent:
      'Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0)',
  },
  {
    visit_dt: new Date(),
    ip: '127.0.0.1',
    user_agent:
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 15.7; rv:143.0) Gecko/20100101 Firefox/143.0',
  },
  {
    visit_dt: new Date(),
    ip: '10.0.0.1',
    user_agent:
      'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:143.0) Gecko/20100101 Firefox/143.0',
  },
  {
    visit_dt: new Date(),
    ip: '192.168.1.52',
    user_agent:
      'Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0)',
  },
  {
    visit_dt: new Date(),
    ip: '10.0.1.5',
    user_agent:
      'Mozilla/5.0 (Windows NT 10.0; Trident/7.0; rv:11.0) like Gecko',
  },
  {
    visit_dt: new Date(),
    ip: '10.0.0.150',
    user_agent:
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36',
  },
]);
```

This aligns with the application configuration in `AppModule`, which defaults to:

```ts
mongodb://localhost:27017/tech_challenge
```

when `MONGODB_URI` is not explicitly provided.

## 2.2 Integration with the MongoDB Container

Instead of implementing a custom init container or embedding initialization logic directly into the application, the solution leverages the **built-in initialization mechanism** of the official MongoDB Docker image.

Any `.js` file mounted into:

```text
/docker-entrypoint-initdb.d/
```

is automatically executed on the **first startup** of the MongoDB container (while the data directory is still empty).

In `02 MongoDB/docker-compose.yml`, the MongoDB service is configured as follows:

```yaml
mongo:
  image: mongo:7
  container_name: BizAwayMongoDB
  restart: unless-stopped
  environment:
    MONGO_INITDB_ROOT_USERNAME: root
    MONGO_INITDB_ROOT_PASSWORD: supersecurepassword
    MONGO_INITDB_DATABASE: admin
  ports:
    - "27017:27017"
  volumes:
    - mongo-data:/data/db
    - ../main/init_scripts/mongo-init.js:/docker-entrypoint-initdb.d/mongo-init.js:ro
  healthcheck:
    test: ["CMD", "mongosh", "admin", "--username", "root", "--password", "supersecurepassword", "--eval", "db.adminCommand('ping')"]
    interval: 10s
    timeout: 5s
    retries: 6
```

Key points:

- The initialization script is mounted as a read-only file into `/docker-entrypoint-initdb.d/`.
- On first startup, MongoDB:
  - Creates the `tech_challenge` database.
  - Creates the `visits` collection.
  - Inserts the initial seed data.
- The `mongo-data` volume ensures that initialization runs only once; subsequent restarts reuse the existing data.

## 2.3 Application Startup Ordering

To ensure that the NestJS application only starts once the database is ready and initialized, the backend service is configured to depend on a healthy MongoDB instance:

```yaml
backend:
  build:
    context: ..
    dockerfile: 01 Dockerfile/Dockerfile
  image: bizaway/bizawayapi
  container_name: BizAwayAPI
  depends_on:
    mongo:
      condition: service_healthy
  environment:
    MONGODB_URI: mongodb://root:supersecurepassword@mongo:27017/tech_challenge?authSource=admin
    NODE_ENV: production
  ports:
    - "3000:3000"
  restart: unless-stopped
```

This configuration guarantees that:

1. MongoDB starts, runs the `mongo-init.js` initialization script, and exposes the `tech_challenge` database with seeded data.
2. The MongoDB healthcheck reports the service as healthy (`db.adminCommand('ping')`).
3. Only then is the NestJS container started and connected to the initialized database.

## 2.4 Design Rationale

The chosen approach has several advantages:

- **Simplicity**: Reuses the native initialization hooks of the official MongoDB image instead of reinventing a custom mechanism.
- **Idempotence**: Initialization scripts are executed only when the data directory is empty, which prevents repeated seeding on every restart.
- **Separation of concerns**: Database initialization is handled by the database container, not by application code.
- **Portability**: The same initialization logic can be reused in Kubernetes by mounting the script via a `ConfigMap` or volume and attaching it to a MongoDB pod or init container.

<br><br><br>

---

# 3. Local Orchestration

This section describes the local orchestration environment designed to run both the **NestJS backend** and **MongoDB** using Docker Compose.  
The goal is to provide a fully reproducible, isolated, and self-initializing local environment that mirrors real deployment conditions.

## 3.1 Overview

The local environment consists of two services:

1. **MongoDB**  
   - Provides persistent storage  
   - Automatically runs an initialization script during first startup  
   - Includes a healthcheck to ensure readiness before backend startup  

2. **BizAwayAPI (NestJS application)**  
   - Built from the project's multi-stage Dockerfile  
   - Connects to MongoDB via an environment-provided URI  
   - Starts only after MongoDB becomes healthy  

This setup ensures a deterministic and stable development flow.

## 3.2 Docker Compose File

The `docker-compose.yml` file (located in `02 MongoDB/`) contains the following configuration:

```yaml
services:
  mongo:
    image: mongo:7
    container_name: BizAwayMongoDB
    restart: unless-stopped
    environment:
      MONGO_INITDB_ROOT_USERNAME: root
      MONGO_INITDB_ROOT_PASSWORD: supersecurepassword
      MONGO_INITDB_DATABASE: admin
    ports:
      - "27017:27017"
    volumes:
      - mongo-data:/data/db
      - ../main/init_scripts/mongo-init.js:/docker-entrypoint-initdb.d/mongo-init.js:ro
    healthcheck:
      test: ["CMD", "mongosh", "admin", "--username", "root", "--password", "supersecurepassword", "--eval", "db.adminCommand('ping')"]
      interval: 10s
      timeout: 5s
      retries: 6

  backend:
    build:
      context: ..
      dockerfile: 01 Dockerfile/Dockerfile
    image: bizaway/bizawayapi
    container_name: BizAwayAPI
    depends_on:
      mongo:
        condition: service_healthy
    environment:
      MONGODB_URI: mongodb://root:supersecurepassword@mongo:27017/tech_challenge?authSource=admin
      NODE_ENV: production
    ports:
      - "3000:3000"
    restart: unless-stopped

volumes:
  mongo-data:
```

## 3.3 Service Responsibilities

### **MongoDB Service**

✔ Provides a persistent MongoDB instance  
✔ Automatically executes the initialization script:

```
/docker-entrypoint-initdb.d/mongo-init.js
```

✔ Open for local testing via `localhost:27017`  
✔ Includes a robust healthcheck ensuring the server is ready before dependent services run  
✔ Stores data in a named volume (`mongo-data`)

### **Backend Service (BizAwayAPI)**

✔ Built from the multi-stage Dockerfile previously described   
✔ Waits for MongoDB's healthcheck before starting (`depends_on: condition: service_healthy`)  
✔ Exposes port `3000` for local interactions  
✔ Reads `MONGODB_URI` from environment variables

## 3.4 Startup Flow

The orchestration follows this sequence:

```text
┌──────────────────┐
│ docker compose up │
└─────────┬────────┘
          │
          ▼
┌──────────────────┐
│ MongoDB container │
│   starts          │
│ - creates admin   │
│ - runs init .js   │
│ - loads dataset   │
└─────────┬────────┘
          │ healthcheck OK
          ▼
┌──────────────────┐
│ BizAwayAPI starts │
│ - connects to DB  │
│ - exposes :3000   │
│ - writes visits   │
└──────────────────┘
```

This ensures reliable, repeatable startup with correct dependencies and ready-to-use database state.

## 3.5 How to Run the Environment

Inside `/BizAway/02 MongoDB` execute:

### **Start**
```bash
docker compose up --build
```

### **Stop (but keep containers)**
```bash
docker compose stop
```

### **Stop and remove containers**
```bash
docker compose down
```

### **Stop and remove containers + volume (reset DB)**
```bash
docker compose down --volumes
```

## 3.6 Verification Steps

After running:

```bash
docker compose up --build
```

### ✔ Check backend running
Visit:

```
http://localhost:3000
```

You should receive visitor information.

### ✔ Check seeded data

```bash
docker exec -it BizAwayMongoDB mongosh -u root -p supersecurepassword
```

Then:

```js
use tech_challenge
db.visits.count()
db.visits.find().pretty()
```

You should see both:
- Seeded documents from the init script  
- Visit logs created by the NestJS application  

## 3.7 Design Rationale

This orchestration approach was chosen because:

- **Reliability** → MongoDB initializes itself with its native mechanism  
- **Repeatability** → Same environment every time  
- **Isolation** → No dependencies installed on the host machine  
- **Security** → Uses internal Docker network instead of exposing MongoDB publicly  
- **Automation** → Backend builds automatically from the Dockerfile  
- **Dependency awareness** → Backend waits for a healthy database  

<br><br><br>

---

# 4. Automation (CI/CD)

This section describes the CI/CD pipeline implemented using GitHub Actions.  
The objective of the pipeline is to provide a reliable, automated validation and packaging workflow for the application before it is deployed or integrated into other environments.

The pipeline configuration is stored in:

.github/workflows/ci.yml

## 4.1 CI Pipeline Overview

The pipeline is triggered on every push and pull request targeting the `main` branch.  
Its purpose is to validate the application and produce a reproducible container image.

The workflow is composed of three jobs:

### **1. test**
- Installs dependencies using pnpm  
- Executes the full Jest test suite  
- Ensures changes are validated before any image is built  

This job uses the project directory `main/` as its working directory, keeping the test stage lightweight and isolated.

### **2. docker-build**
- Builds the production Docker image using the multi-stage Dockerfile located in `01 Dockerfile/`  
- Assigns an immutable tag based on the Git commit SHA (e.g., `ci-a1b2c3d`)  
- Saves the resulting image to a tarball using `docker save`  
- Uploads the tarball as a GitHub Actions artifact so it can be retrieved in subsequent jobs  

This approach decouples the image build stage from the smoke-testing stage.

### **3. smoke-test**
- Downloads the Docker image artifact produced by the previous job  
- Loads it into the runner's local Docker engine  
- Runs a lightweight verification to ensure the container can start cleanly  

The smoke test intentionally keeps validation minimal, focusing only on whether the container can execute a basic Node.js command without failing.  
This provides early detection of packaging issues (e.g., missing dependencies, corrupt build output).

## 4.2 Design Rationale

The workflow follows a minimal and practical CI design:

- **Fail-fast**: Tests must pass before building the Docker image. Smoke tests only run if the build succeeds.
- **Separation of concerns**: Each job has a single responsibility (testing, building, validating the image).
- **Reproducibility**: Builds use the lockfile and a multi-stage Dockerfile to ensure consistent output.
- **Artifact reuse**: The Docker image is built once and transferred as an artifact instead of being rebuilt in later jobs.
- **Traceability**: Images are tagged with the short commit SHA, providing clear correlation between code and artifacts.

This structure keeps the pipeline deterministic, maintainable, and easy to extend with future deployment stages.

<br><br><br>

---

# 5. Security Hardening

This section describes the security measures applied to the application environment.  
The focus is on:  

- Proper secrets management  
- Secure container configuration  
- Enforcing least privilege inside containers  

These controls ensure that both the application and its supporting services follow secure operational practices.

## 5.1 Secure Container Configuration

### 5.1.1 Non-Root User Execution

The production container does not run as the root user.  
A dedicated non-privileged user (bizuser) is created in the final stage of the multi-stage Dockerfile.

Key benefits:
- Reduces the impact of a potential compromise
- Prevents modification of system-level paths inside the container
- Aligns with container security best practices and CIS Benchmarks

### 5.1.2 Minimal Runtime Image

The final production stage includes only:
- Compiled application code (dist/)
- Production dependencies
- No development tools (TypeScript compiler, build tooling, source code)

This minimizes:
- Attack surface
- Risk of code tampering
- Image size and build time

### 5.1.3 Least Privilege by Design

Additional hardening choices:
- No unnecessary system packages are installed
- The container exposes only port 3000
- Permissions inside /srv/app are restricted so only bizuser can modify the directory
- NODE_ENV is set to production to disable dev features automatically

These practices ensure the runtime environment contains only what is strictly necessary.

## 5.2 Secrets Management

### 5.2.1 Secrets Provided via Environment Variables

Secrets such as database passwords and URIs are typically injected at runtime using environment variables, with a secrets manager.  

This prevents credentials from being embedded in:
- Source code
- Git history
- The Docker image layers

For this challenge, credentials are intentionally simple and visible.  
In a production environment, they would be stored in dedicated secret management systems such as:
- Jenkins secrets manager
- AWS Secrets Manager
- Hashicorp Vault
- Any other equivalent

### 5.2.2 Configuration Decoupled from Code

The backend application reads configuration exclusively from environment variables.  
This makes the deployment flexible and secure by enabling:

- Secret rotation without rebuilding Docker images
- Using different credentials per environment (devel, pre, production)
- Preventing accidental credential leaks through Git or Docker layers

## 5.3 Summary

Security controls applied in this project include:
- Running containers as a non-root user
- Restricting file permissions and exposed ports
- Using minimal runtime images to reduce attack surface
- Injecting secrets at runtime instead of embedding them in images (ideally)
- Ensuring credentials and configuration remain decoupled from code

Together, these controls provide a hardened and production-ready execution environment.

## 5.4 Additional Hardening Practices in Professional Environments

Beyond the measures implemented for this challenge, production-grade environments typically include additional layers of security:

- **Static Application Security Testing (SAST):** Tools such as SonarQube, Semgrep, or GitHub CodeQL analyze the source code to detect insecure patterns before deployment. Other security focused tools also exist (Wiz for example).

SAST analyzes the application’s own source code, while SCA focuses on vulnerabilities coming from third-party libraries and dependencies.

- **Dependency and Supply-Chain Scanning:** Tools like Snyk, Dependabot, Trivy, or Grype identify vulnerable third-party libraries.

- **Container Image Scanning:** Performed during CI to detect OS-level vulnerabilities or insecure Docker configurations. (Trivy, for example). Container image scanning is typically integrated into CI pipelines and executed after the Docker build stage. 

Tools like Trivy allow scanning images for:
- OS-level vulnerabilities (Alpine, Debian, etc.)
- Language-level vulnerabilities (npm/pnpm packages)
- Misconfigurations (exposed ports, hardcoded secrets, weak users)
- Dependency vulnerabilities (CVE-based)

- **Runtime Security Controls:** Technologies such as Falco, AppArmor, or seccomp restrict container behavior and detect anomalies at runtime.

- **Network Segmentation and Zero-Trust Controls:** Restrict communication between services and prevent unnecessary exposure of internal components.

- **Secret Rotation and Centralized Secret Managers:** Production secrets are rotated automatically and retrieved at runtime without embedding them into CI pipelines.

- **Audit and Observability:** Application logs, access logs, and deployment audit trails contribute to operational security and incident response readiness. (SIEM with with anomaly detection and automated alerting)

These additional measures form a layered defense strategy aligned with modern DevSecOps practices.

<br><br><br>

---

# 6. Infrastructure as Code (IaC)

This section describes the Terraform configuration used to provision the cloud infrastructure required to deploy the Kubernetes cluster on **AWS Elastic Kubernetes Service (EKS)**.  
The IaC structure follows modular best practices and separates reusable infrastructure modules from environment-specific configurations.

## 6.1 Objectives

The Terraform configuration provisions the foundational infrastructure needed to run the application on Kubernetes:

- A dedicated **VPC** with private and public subnets  
- An **EKS cluster** to host the application workloads  
- One or more **Node Groups** providing compute capacity  
- Environment-specific variables for **dev** and **prod**  
- A clean and extensible module architecture  

The setup aligns with AWS and Terraform best practices used in production environments.

## 6.2 Project Structure

The IaC folder is organized as follows:

```text
06 Infrastructure as Code (IaC)/
└── terraform
├── environments
│ ├── dev
│ │ ├── backend.tf
│ │ └── terraform.tfvars
│ └── prod
│ ├── backend.tf
│ └── terraform.tfvars
├── main.tf
├── modules
│ ├── eks
│ │ ├── main.tf
│ │ ├── outputs.tf
│ │ └── variables.tf
│ ├── node_group
│ │ ├── main.tf
│ │ ├── outputs.tf
│ │ └── variables.tf
│ └── vpc
│ ├── main.tf
│ ├── outputs.tf
│ └── variables.tf
├── outputs.tf
├── providers.tf
├── README.md
├── variables.tf
└── versions.tf
```


### Rationale for This Layout

- **modules/** contains reusable components (VPC, EKS, Node Groups).
- **environments/** provides isolated configurations for dev and prod.
- Root files (`main.tf`, `variables.tf`, `providers.tf`) orchestrate module composition.
- This is the standard and recommended Terraform design for real-world teams.

## 6.3 Module Responsibilities

### 6.3.1 VPC Module

The VPC module provisions:

- A dedicated AWS VPC  
- Public and private subnets across multiple Availability Zones  
- Internet Gateway and NAT Gateways  
- Routing tables with correct associations  

This provides a secure and isolated network layer for workloads running in EKS.

Key benefit: the cluster and nodes run in **private subnets**, improving security and reducing public exposure.

### 6.3.2 EKS Module

The EKS module creates:

- The EKS control plane  
- Required IAM roles (cluster role, OIDC provider)  
- Cluster endpoint and certificate outputs  

EKS is fully managed by AWS; the Terraform module ensures correct integration with networking and node groups.

### 6.3.3 Node Group Module

The node group module provisions:

- One or more managed node groups  
- IAM instance profiles  
- Desired / min / max scaling configuration  
- kubelet CPU/Memory values via userdata if needed  

Node groups run in private subnets and provide the compute layer for Kubernetes workloads.

## 6.4 Environment-Specific Configuration

Each environment (`dev` and `prod`) contains:

- A `backend.tf` file defining state storage (local for this challenge)
- A `terraform.tfvars` file providing:
  - CIDR blocks  
  - Instance types  
  - Cluster name  
  - Scaling parameters  

Example values might differ by environment:

| Setting | dev | prod |
|--------|-----|-------|
| instance type | t3.small | t3.medium |
| desired nodes | 2 | 4 |
| max nodes | 3 | 8 |
| VPC size | smaller | larger |

This makes environments reproducible, isolated, and easy to extend.

## 6.5 Workflow: How the IaC Is Executed

To deploy the infrastructure, navigate to the desired environment and run:

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

Terraform then provisions:

1. The VPC
2. The EKS control plane
3. The node groups
4. IAM permissions

Once applied, Kubernetes credentials can be retrieved with:

```bash
aws eks update-kubeconfig --name <cluster_name> --region <region>
```

## 6.6 Design Rationale

This approach follows the same structure used in enterprise Terraform deployments:

- Modular architecture → components can be reused, replaced, or extended independently
- Environment separation → dev/prod have isolated states and configuration boundaries
- Declarative and reproducible → infrastructure changes are tracked via Git
- Scalable → new environments (qa, staging, perf) can be added effortlessly
- Auditable → Terraform state and plans provide traceability over changes

The result is a maintainable and production-grade IaC foundation suitable for cloud-native applications.

<br><br><br>

---

# 7. Kubernetes Manifests

This section describes the Kubernetes manifests defined for deploying both the BizAway API and its MongoDB database onto the EKS cluster provisioned via Terraform.

The manifests are stored in the repository under:

```text
07 Kubernetes Deployment/
├── base
│   ├── api
│   │   ├── configmap.yaml
│   │   ├── deployment.yaml
│   │   ├── secret.yaml
│   │   └── service.yaml
│   ├── mongo
│   │   ├── secret.yaml
│   │   ├── service.yaml
│   │   └── statefulset.yaml
│   ├── ingress
│   │   └── ingress.yaml
│   └── namespace
│       └── namespace.yaml
└── overlays
    ├── dev
    └── prod
```

They are split into logical units (namespace, configuration, secrets, application, database, and ingress) and follow Kubernetes best practices in terms of security, observability, and resource management.

Manifests under base/ define the common, environment-agnostic configuration, while overlays/dev and overlays/prod provide environment-specific patches (for example, replica counts, resource limits, or hostnames).

## 7.1 Resource Overview

The Kubernetes layer includes the following resources:

| Component     | Resource Types                                                                 |
|---------------|-------------------------------------------------------------------------------|
| Namespace     | Namespace                                                                     |
| API backend   | Deployment, Service (ClusterIP), ConfigMap, Secret                            |
| MongoDB       | StatefulSet, Service (ClusterIP), Secret, PersistentVolumeClaim               |
| *Ingress (EKS) | Ingress with AWS ALB + TLS (AWS ACM certificate)                              |

*On an AWS EKS cluster, this Ingress is meant to be used together with the AWS Load Balancer Controller in order to provision an ALB. TLS termination is typically handled by AWS ACM certificates referenced from the Ingress resource via annotations. For this challenge, the focus is on the Ingress resource design; installing and wiring the controller is considered out of scope but follows standard EKS practices.

The API backend and MongoDB are deployed in the same namespace but remain decoupled at the manifest level. Ingress acts as the external entry point through AWS ALB.

## 7.2 Application Deployment (BizAway API)

The BizAway API is deployed using a Kubernetes **Deployment**, with the following characteristics:

- **Replicas:** minimum of 2 for basic high availability.
- **Security Context:** `runAsNonRoot` with an explicit UID, aligned with the Dockerfile.
- **Configuration via ConfigMap:** non-sensitive values (e.g., `NODE_ENV`).
- **Secrets:** sensitive values (e.g., `MONGODB_URI`) are injected through `Secret`.
- **Resource Requests/Limits:** defined to ensure predictable scheduling and avoid noisy-neighbour problems.
- **Probes:**
  - **Readiness probe:** ensures traffic is only routed to ready pods.
  - **Liveness probe:** restarts unhealthy containers automatically.

These configurations guarantee controlled rollout, resilience under failure, and secure runtime execution.

## 7.3 Database Deployment (MongoDB)

MongoDB is deployed as a **StatefulSet** to guarantee stable network identity and persistent storage.

Key characteristics:

- **StatefulSet with stable identities** (`mongo-0`, `mongo-1`, etc.).
- **Automatic Persistent Volume Claims** through `volumeClaimTemplates`.
- **Credentials stored in Kubernetes Secrets**, never hardcoded.
- **Cluster-internal Service only (no external exposure)**.
- **Health probes** to verify responsiveness and restart containers when necessary.
- **Resource requests/limits** to ensure predictable performance.

Although a single replica is enough for this challenge, using a StatefulSet prepares the service for production-grade scaling.

## 7.4 Configuration and Secret Management

Both the API and MongoDB follow the same principle:

- **ConfigMaps** manage non-sensitive configuration.
- **Secrets** are used for credentials and connection strings.
- **No credential is baked into Docker images or source code.**
- **Environment-agnostic manifests:** values can be overridden per environment (dev, staging, production).

This aligns with the project’s security posture (least privilege, non-root execution, no credentials in images).

## 7.5 Networking, Load Balancing and TLS on EKS

- The API is exposed internally through a **ClusterIP Service**.
- MongoDB is reachable only internally through a **separate ClusterIP Service**.
- External access is provided ONLY through an **Ingress**, managed by the **AWS Load Balancer Controller (ALB)**.
- **TLS termination** occurs at the ALB level using **AWS ACM certificates**.
- Ingress uses annotations to provision the ALB automatically.

**Benefits:**

- The database is never externally reachable.
- Only HTTPS traffic reaches the cluster boundary.
- TLS is centrally managed via ACM.
- Routing and security scales with multiple applications.

## 7.6 Deployment Flow

After provisioning EKS and configuring `kubectl`, deployment can occur via GitOps (ArgoCD/Flux) or manually:

Kubernetes will automatically:

1. Create the namespace.
2. Load ConfigMaps and Secrets.
3. Deploy MongoDB StatefulSet and internal Service.
4. Deploy BizAway API Deployment and Service.
5. Provision Ingress and ALB with TLS support.

## 7.7 Design Rationale

The Kubernetes manifests were designed to:

- Preserve the same security posture as the Docker image (non-root, least privilege).
- Avoid credential leakage through ConfigMaps/Secrets separation.
- Allow horizontal scaling through Deployment replicas.
- Improve resilience through probes and rolling updates.
- Support persistent state for the database using StatefulSet + PVC.
- Provide secure external access through AWS ALB + TLS.

<br><br><br>

---

# 8. Monitoring and Observability

This section describes the monitoring and observability approach for the BizAway application and its underlying infrastructure.

The primary goals are:

- Track **request latency** and **throughput**
- Measure **error rates**
- Monitor **container and pod health** (restarts, CPU, memory)
- Provide a **dashboard** suitable for day-to-day operations and incident troubleshooting

The solution is based on the standard Kubernetes/DevOps stack:

- **Prometheus** for metrics collection
- **Grafana** for visualization
- **Kubernetes probes and events** for container health

In a real EKS environment, these components are typically installed via Helm (e.g. `kube-prometheus-stack`). For this challenge, the focus is on the design and integration points rather than a full cluster installation.

For this challenge, the full installation is not committed to the repository, but the monitoring design follows the same patterns used by kube-prometheus-stack on EKS.

## 8.1 Metrics Strategy

Monitoring is split into three layers:

1. **Application-level metrics**
2. **Container / pod metrics**
3. **Cluster-level metrics**

### Application Metrics

The NestJS application can expose a dedicated metrics endpoint using a Prometheus client library (for example, a NestJS Prometheus module). Typical application-level metrics include:

- Total number of HTTP requests
- HTTP request duration per route
- Number of 4xx and 5xx responses
- Custom business metrics (e.g. number of visits stored in MongoDB)

These metrics can be exported as Prometheus-readable format and scraped by Prometheus at a fixed interval.

### Container and Pod Metrics

Kubernetes already exposes container-level metrics that can be scraped by Prometheus:

- CPU usage per pod/container
- Memory usage and limits
- Pod restarts
- Node resource utilization

These metrics are crucial to detect resource exhaustion, misconfigured limits/requests, and crash loops.

### Cluster Metrics

At the cluster level, EKS and Kubernetes components (API server, scheduler, etc.) provide metrics for:

- API server request rate and error rate
- Node availability
- Scheduling performance

Although not strictly required for this challenge, they are important in a full production setup.

## 8.2 Prometheus Integration

In a typical EKS deployment:

- Prometheus is deployed inside the cluster (often via `kube-prometheus-stack`).
- A `ServiceMonitor` or `PodMonitor` is used (via Prometheus Operator) to discover and scrape metrics endpoints.
- The BizAway API exposes `/metrics` on the same port as the application.

The scraping configuration allows Prometheus to collect:

- Application metrics exported by the NestJS app
- Kubernetes metrics from the kubelet/cAdvisor
- Metrics from MongoDB if a suitable exporter is deployed (optional for this challenge)

Retention and scraping intervals can be adjusted depending on environment (e.g. dev vs prod).

## 8.3 Container Health and Probes

The same Kubernetes manifests used for deployment already contribute to observability:

- **Readiness probes** ensure that only healthy pods receive traffic.
- **Liveness probes** cause pods to be restarted if they stop responding.

Together with Prometheus metrics (e.g. container restarts, pod status), this provides visibility over container health and enables alerting policies such as:

- High rate of pod restarts
- Pods in `CrashLoopBackOff`
- Readiness probe failures for a sustained period

## 8.4 Example Grafana Dashboard

A dedicated Grafana dashboard can be used to monitor the BizAway API.  
The following panels are representative of a production-ready view:

1. **Request Rate (RPS)**
   - Metric: total HTTP requests per second
   - Purpose: understand overall traffic and load patterns

2. **Request Latency (P50 / P95 / P99)**
   - Metric: HTTP request duration histogram/summary
   - Panels:
     - Median latency (P50)
     - Tail latency (P95/P99)
   - Purpose: detect performance regressions and slow endpoints

3. **Error Rate**
   - Metric: share or rate of 4xx and 5xx responses
   - Purpose: quickly detect failures in application logic or downstream dependencies

4. **Pod and Container Health**
   - Panels for:
     - Number of ready replicas
     - Pod restarts per pod
     - Pod status (Running/Pending/CrashLoopBackOff)
   - Purpose: monitor deployment stability and health

5. **Resource Utilization**
   - CPU usage vs CPU requests/limits per pod
   - Memory usage vs memory requests/limits per pod
   - Purpose: validate that resource settings are realistic and avoid throttling or OOM kills

6. **MongoDB Health (optional)**
   - If a MongoDB exporter is added:
     - Connections count
     - Query rate
     - Storage usage
   - Purpose: detect DB bottlenecks or saturation conditions

The dashboard is designed to give a quick “red/green” view for:

- Performance (latency and throughput)
- Correctness (error rates)
- Capacity (CPU/memory utilization)
- Stability (restarts, probe failures)

## 8.5 Logging and Future Extensions

Although not fully implemented in this challenge, the monitoring setup can be extended with:

- **Centralized Logging:** shipping application and container logs to a system such as ELK/Opensearch, Loki, or CloudWatch Logs for search and correlation.
- **APM Tracing:** using tools such as OpenTelemetry to trace requests across services (API → MongoDB).
- **Alerting:** defining alert rules in Prometheus based on thresholds (error rate spikes, high latency, repeated restarts) and sending notifications to Slack, email or on-call systems.

This ensures that the BizAway platform can evolve from basic metrics visibility to full observability and incident response over time.

<br><br><br>

---

# 10. Enhancements (Bonus)

This section describes optional improvements that were considered or partially designed to further harden and industrialize the platform.  
They are not strictly required for the challenge, but they illustrate how the current solution could evolve in a production environment.

The main advanced topics are:

- GitOps-based delivery
- External secret management (AWS Secrets Manager)
- Horizontal autoscaling
- Network-level isolation with NetworkPolicies
- Advanced TLS management
- SRE-oriented monitoring and alerting

## 10.1 GitOps Delivery (Argo CD / Flux)

Instead of applying Kubernetes manifests manually, a production-ready setup would use a **GitOps controller** such as **Argo CD** or **Flux**.  

In this model:

- The `07 Kubernetes Deployment/` directory becomes the **single source of truth** for runtime configuration.
- A GitOps controller continuously watches the Git repository:
  - When manifests change in the main branch, the controller applies the changes automatically to the cluster.
  - The actual state of the cluster is reconciled towards the desired state stored in Git.
- Rollbacks are as simple as `git revert`, making deployments auditable and reversible.

This complements the Terraform IaC approach used for the cluster itself:

- Terraform manages **cluster and infrastructure** (VPC, EKS, node groups, IAM).
- GitOps manages **workload-level configuration** (Deployments, Services, Ingress, ConfigMaps, Secrets references).

## 10.2 Secrets Management via AWS Secrets Manager

For the challenge, credentials are kept simple and supplied via Kubernetes Secrets / environment variables.  
In a full production environment on AWS, it is recommended to externalize secret management to:

- **AWS Secrets Manager** or
- **AWS Systems Manager Parameter Store**

The intended design would be:

- Database credentials and other sensitive values are stored in AWS Secrets Manager.
- Kubernetes-specific components (e.g. `external-secrets` operator) synchronize those secrets into Kubernetes Secrets automatically.
- Pods never receive secrets directly from CI; they are fetched at runtime via Kubernetes-native mechanisms.

Benefits:

- Centralized rotation of secrets without redeploying workloads.
- Unified audit trail for secret access.
- Reduced risk of accidental exposure in CI logs or Git history.

## 10.3 Horizontal Autoscaling (HPA + Cluster Autoscaler)

The current Deployment configuration uses fixed replica counts (e.g. 2 replicas).  
To scale with real traffic, the following components can be added:

- **Horizontal Pod Autoscaler (HPA)** for the BizAway API:
  - Scales the number of pods based on CPU usage, memory usage or custom application metrics (e.g. request rate).
  - For example, the API could scale from 2 to 10 replicas when CPU exceeds 70%.

- **Cluster Autoscaler** (or Karpenter) on EKS:
  - Automatically adjusts the number of worker nodes based on pending pods.
  - Ensures that the cluster has enough capacity to run additional replicas when required by the HPA.

This combination enables true elasticity:

- Under light load, the system runs with minimal cost.
- Under heavy load, both pods and underlying nodes scale up to maintain SLOs.

## 10.4 Network Policies for Zero-Trust Networking

The current Kubernetes design ensures that MongoDB is not exposed externally and the API is only exposed through an Ingress.  
To further harden internal communication, **Kubernetes NetworkPolicies** can be introduced:

- Only the BizAway API pods are allowed to connect to the MongoDB Service.
- The API is allowed to receive traffic from:
  - The Ingress/ALB routing layer.
  - Other internal services (if needed) that are explicitly whitelisted.
- All other traffic inside the namespace is denied by default (default deny policy).

This approach implements a **zero-trust networking model** inside the cluster:

- Lateral movement becomes much more difficult in case of a compromised pod.
- The database surface area is drastically reduced.

## 10.5 Advanced TLS Management

For the main scenario, TLS termination is handled by the **AWS Application Load Balancer (ALB)** using a certificate stored in **AWS Certificate Manager (ACM)** and attached to the Ingress via annotations.

In more complex environments, additional TLS options could be considered:

- **Dedicated internal CAs** for non-public services.
- Use of **cert-manager** to automatically:
  - Request and renew certificates from ACME providers (e.g., Let’s Encrypt) for non-ALB scenarios.
  - Issue internal TLS certificates for in-cluster communication.

This would further improve transport-layer security, especially in multi-tenant or compliance-sensitive environments.

## 10.6 SRE-Oriented Monitoring and Alerting

Section 8 described the foundation for metrics (Prometheus) and dashboards (Grafana).  
To move towards an SRE-oriented model, the following enhancements can be added:

- **Service Level Objectives (SLOs):**
  - Example: “99% of HTTP requests must complete under 300 ms over a 30-day window.”
  - Example: “Error rate (5xx) must remain below 1% of total requests.”

- **Alerting Rules:**
  - High error rate on the API (e.g. 5xx > 5% for more than 5 minutes).
  - Latency SLO violations (e.g. P95 latency above a defined threshold).
  - Pods in CrashLoopBackOff or repeated restarts.
  - Node or cluster resource exhaustion (CPU, memory, disk).

- **Integration with incident channels:**
  - Prometheus Alertmanager can route alerts to:
    - Slack
    - Email
    - Pager/on-call platforms (PagerDuty, Opsgenie, etc.)

- **Centralized Logging and Correlation:**
  - Logs from application pods and infrastructure sent to:
    - ELK / OpenSearch
    - Loki + Grafana
    - CloudWatch Logs in AWS
  - Ability to pivot from a metric (e.g. spike in 5xx) to related logs for root cause analysis.

These additions complete the picture from simple “monitoring” to real **observability + incident response**, which is what SRE teams expect in production systems.
