### What this app does?

Deploys the Nuon BYOC control plane into your GCP project — the platform that enables vendors to install and operate software in customer cloud networks. Includes the Nuon API, web dashboard, Temporal workflow engine, ClickHouse analytics, and supporting data infrastructure.

### Prerequisites

- A valid GCP project

### How to install/What to expect next?

- Clicking install will generate a Terraform install stack for you to apply in your GCP project which creates the VPC network, Compute Engine VM, and a runner, an agent that receives jobs to deploy the Nuon control plane in your project
- If configured, you may be prompted to approve plan steps
- Average installation time is 60–90 minutes due to creating the VPC network, GKE cluster, Cloud SQL databases, ClickHouse, Temporal, and all application services

### What gets deployed in your cloud account?

- Dedicated VPC network
- Google Kubernetes Engine (GKE) cluster
- Two Cloud SQL PostgreSQL databases (Nuon control plane + Temporal)
- GCS buckets (application storage + ClickHouse backups)
- ClickHouse analytics cluster (server + keeper nodes)
- Temporal workflow engine (server + UI)
- Nuon CTL API and Dashboard UI
- Google Cloud Load Balancers (GKE Ingress)
- Google-managed wildcard TLS certificate (Certificate Manager)
- Workload Identity service accounts
- Optional Datadog observability integration

```mermaid

  graph TD

      subgraph Nuon["Nuon Control Plane (Upstream)"]
          NuonAPI["Nuon API"]
      end

      subgraph Clients["Clients"]
          Vendor["Vendor"]
          Browser["Web browser"]
          Vendor ~~~ Browser
      end

      subgraph VPC["Customer Cloud Network (GCP)"]
          Stack["Terraform Install Stack"]
          Runner["Nuon Runner"]

          subgraph GKE["GKE Cluster"]
              Ingress["GKE Ingress Controller"]
              CtlAPI["Nuon CTL API"]
              Dashboard["Dashboard UI"]
              Temporal["Temporal Server"]
              ClickHouse["ClickHouse Cluster"]
          end

          CertManager["Google-managed Wildcard Certificate"]
          GLB["Cloud Load Balancer"]

          subgraph Data["Data Tier"]
              SQL_Nuon["Cloud SQL PostgreSQL (Nuon)"]
              SQL_Temporal["Cloud SQL PostgreSQL (Temporal)"]
              GCS["GCS Buckets"]
          end
      end

      NuonAPI -->|generates| Stack
      Stack -->|provisions| Runner
      Runner -->|provisions| GKE
      Runner -->|provisions| Data

      Ingress -->|creates| GLB
      CertManager -->|TLS| GLB

      Browser -->|HTTPS app.*| GLB
      Vendor -->|HTTPS api.*| GLB
      GLB --> CtlAPI
      GLB --> Dashboard

      CtlAPI -->|orchestration| Temporal
      Temporal -->|state| SQL_Temporal
      CtlAPI -->|app data| SQL_Nuon
      CtlAPI -->|storage| GCS
      ClickHouse -->|backups| GCS

```

### What inputs can you enter?

**DNS**
- Root domain
- Nuon-managed DNS toggle

**Auth (OAuth / OIDC)**
- OAuth audience, client IDs, issuer URL
- OIDC provider type, client ID, redirect URL, allowed domains

**Infrastructure sizing**
- Cloud SQL instance tiers (Nuon DB, Temporal DB)
- ClickHouse instance types (cluster nodes, keeper nodes)

**Integrations (optional)**
- GitHub App credentials
- Datadog API/app keys
- Email service API key (Loops)

**Nuon**
- Environment (prod/dev)
- Custom runner image URL and tag

### Security & compliance

- [Nuon BYOC trust center](https://docs.nuon.co/guides/vendor-customers)
- All resource provisioning and scripts are performed by an agent in a VM in your network - no cross-project access granted to the vendor
- Workload Identity provides least-privilege IAM access scoped per service
- OIDC/OAuth authentication for API and dashboard access
- Wildcard TLS certificate secures all service endpoints
- Cloud SQL databases deployed on private IPs

### Nuon concepts

The following terminology is core to the Nuon BYOC platform.

#### Connect Your App | App Config
- App (collection of TOML config files that provision and manage the Nuon control plane in your cloud account)
- Sandbox (the underlying infrastructure, in this case a GKE Kubernetes cluster)
- Component (Docker images, Helm charts, and Terraform to deploy the CTL API, Dashboard, Temporal, ClickHouse, Cloud SQL, GCS, Workload Identity, and TLS certificate)
- Inputs (dynamic values specific to the install e.g., root domain, auth credentials, instance types, integration keys)
- Secrets (sensitive values either auto-created or entered by the customer during Stack creation - stored in GCP Secret Manager)

#### Support Customer Infrastructure | Customer Config

- Installs (Installs are instances of an application in your (the customer) cloud account.)
- Stack (the Terraform install stack that provisions the VPC network, subnets, service accounts, and the Compute Engine VM and Runner (agent) Docker service)
- Runners (Egress-only agents deployed in customer cloud accounts that execute all provisioning, deployment, and day-2 operations.)
- Operational Roles (IAM service accounts to perform different operations for least-privilege access across sandbox, components, and actions.)

#### Continuous Delivery | Day-2 Operations

- Workflows (Orchestration of the deployment, update & teardown lifecycle of apps, components, and actions)
- Policies (Rego & Kyverno configs to enforce compliance and security rules at infrastructure plan steps)
- Customer Portal (A customer-facing web dashboard to initiate and monitor an app's install in a customer's VPC)
