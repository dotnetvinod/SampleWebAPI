# CI/CD Setup Guide — Azure DevOps

This solution uses **Azure DevOps Pipelines** with **Environments** and **Variable Groups** for Dev, QA, and Production deployments.

## Pipeline files

| File | Trigger | Purpose |
|------|---------|---------|
| `azure-pipelines.yml` | Push/PR to **`dev`** | Build, test, artifacts; deploy to **Dev + QA** on push |
| `azure-pipelines-prod.yml` | Push to **`main`** / manual | Build, test, deploy to **Production** |

Reusable templates live in `pipelines/templates/`:

- `deploy-database.yml` — runs `Deploy-Database.ps1` via sqlcmd
- `deploy-api.yml` — configures App Service settings and deploys the API artifact

## Branch strategy

| Branch | Pipeline | Deploys to |
|--------|----------|------------|
| `dev` | `azure-pipelines.yml` | **Dev** + **QA** (parallel, on push only) |
| `dev` (PR) | `azure-pipelines.yml` | Build + test only (no deploy) |
| `main` | `azure-pipelines-prod.yml` | **Production** |

## Pipeline flow (push to `dev`)

```mermaid
flowchart LR
    Push[Push to dev] --> Build[Build & Test]
    Build --> Artifact[Publish Artifacts]
    Artifact --> DevDeploy[Deploy Dev]
    Artifact --> QADeploy[Deploy QA]
    DevDeploy --> DevDB[(Dev SQL)]
    DevDeploy --> DevAPI[Dev Web App]
    QADeploy --> QADB[(QA SQL)]
    QADeploy --> QAAPI[QA Web App]
```

Each deployment job runs **database scripts first**, then deploys the **API artifact**.

---

## Azure DevOps setup

### 1. Create the project and connect the repo

1. In Azure DevOps, create a project (or use an existing one).
2. Go to **Repos** → import or push this repository.
3. Go to **Project Settings** → **Service connections** → **New connection** → **Azure Resource Manager**.
4. Name it **`StudentManagement-Azure`** (or update `azureServiceConnection` in the YAML files).

### 2. Create Environments

Go to **Pipelines** → **Environments** → **Create environment**:

| Environment | Purpose | Recommended |
|-------------|---------|-------------|
| `dev` | Development server | No approval |
| `qa` | QA server | Optional approval |
| `prod` | Production server | **Required approvers** |

For `prod`: open the environment → **Approvals and checks** → **Approvals** → add reviewers.

### 3. Create Variable Groups

Go to **Pipelines** → **Library** → **+ Variable group**.

Create three groups and link each to its environment (**Variable group** → **Link secrets from Azure Key Vault** optional):

#### `StudentManagement-Dev`

| Variable | Secret? | Example |
|----------|---------|---------|
| `sqlServer` | No | `cruddev.database.windows.net` |
| `sqlDatabase` | No | `StudentDb_Dev` |
| `sqlUsername` | No | `sqladmin` |
| `sqlPassword` | **Yes** | *(password)* |
| `apiConnectionString` | **Yes** | `Server=tcp:...;Database=StudentDb_Dev;User ID=...;Password=...;Encrypt=True;` |
| `azureWebAppName` | No | `student-api-dev` |

#### `StudentManagement-QA`

Same variables with QA-specific values (`StudentDb_QA`, `student-api-qa`, etc.).

#### `StudentManagement-Prod`

Same variables with production values.

Link variable groups to pipelines in the YAML (already configured):

```yaml
variables:
  - group: StudentManagement-Dev
```

Authorize variable groups when prompted on first pipeline run.

### 4. Create pipelines

**Pipeline 1 — Dev & QA**

1. **Pipelines** → **New pipeline** → select your repo.
2. Choose **Existing Azure Pipelines YAML file**.
3. Select `/azure-pipelines.yml`.
4. Save and run.

**Pipeline 2 — Production**

1. **Pipelines** → **New pipeline** → same repo.
2. Select `/azure-pipelines-prod.yml`.
3. Save.

### 5. SQL permissions

Grant the SQL login used in variable groups permission to create databases (first run) and deploy objects:

```sql
-- On master (Azure SQL): allow login to create databases if needed
-- For existing DB, on target database:
CREATE USER [sqladmin] WITH PASSWORD = '...';  -- if not exists
ALTER ROLE db_owner ADD MEMBER [sqladmin];
```

---

## Database automation

Scripts in `StudentManagement.Database/` run in order via `deploy/deploy-manifest.json`:

1. `001_CreateDatabase.sql` — creates DB on `master` if missing
2. `002_CreateTable.sql` — creates `Students` table
3. `003_StoredProcedures.sql` — creates/alters stored procedures

The pipeline installs `sqlcmd` on Linux agents and runs `Deploy-Database.ps1`.

### Manual local deploy

```powershell
cd StudentManagement.Database
./deploy/Deploy-Database.ps1 `
  -Server "yourserver.database.windows.net" `
  -Database "StudentDb_Dev" `
  -Username "sqladmin" `
  -Password "YourPassword"
```

---

## API configuration per environment

| Environment | `ASPNETCORE_ENVIRONMENT` | Config file |
|-------------|--------------------------|-------------|
| Dev | `Development` | `appsettings.Development.json` |
| QA | `QA` | `appsettings.QA.json` |
| Prod | `Production` | `appsettings.Production.json` |

Connection strings are set on Azure App Service during deployment via `ConnectionStrings__DefaultConnection` — never commit secrets to source control.

---

## Artifacts

On push to `dev`, the pipeline publishes:

| Artifact | Contents |
|----------|----------|
| `api` | Published .NET 8 Web API |
| `database` | SQL scripts + deploy tooling |

Production pipeline publishes the `api` artifact only (database scripts come from repo checkout during deploy).

---

## Customization

### Change service connection name

Edit `azureServiceConnection` in both pipeline YAML files, or override as a pipeline variable in Azure DevOps UI.

### Windows agents / IIS

Replace `deploy-api.yml` with a PowerShell step that copies files to IIS on a self-hosted agent, or use the **IIS web app deploy** task.

### Use Key Vault

Link secrets in variable groups to Azure Key Vault for centralized secret management.

---

## First-time checklist

- [ ] Azure DevOps project created and repo connected
- [ ] Azure Resource Manager service connection (`StudentManagement-Azure`)
- [ ] Environments: `dev`, `qa`, `prod` (with prod approvals)
- [ ] Variable groups: `StudentManagement-Dev`, `StudentManagement-QA`, `StudentManagement-Prod`
- [ ] Two pipelines created from `azure-pipelines.yml` and `azure-pipelines-prod.yml`
- [ ] Azure SQL servers and Web Apps provisioned per environment
- [ ] Push `dev` branch to trigger Dev + QA deployment
- [ ] Merge to `main` for production release
