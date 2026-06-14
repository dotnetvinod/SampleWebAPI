# CI/CD Setup Guide

This solution uses **GitHub Actions** with **GitHub Environments** for Dev, QA, and Production deployments.

## Branch strategy

| Branch | Trigger | Deploys to |
|--------|---------|------------|
| `dev`  | Push / PR (build+test only on PR) | **Dev** + **QA** (on push) |
| `main` | Push / manual dispatch | **Production** (requires approval if configured) |

## Pipeline flow (push to `dev`)

```mermaid
flowchart LR
    Push[Push to dev] --> Build[Build & Test]
    Build --> Artifact[Upload Artifacts]
    Artifact --> DevDeploy[Deploy Dev]
    Artifact --> QADeploy[Deploy QA]
    DevDeploy --> DevDB[(Dev SQL)]
    DevDeploy --> DevAPI[Dev Web App]
    QADeploy --> QADB[(QA SQL)]
    QADeploy --> QAAPI[QA Web App]
```

Each deploy job runs **database scripts first**, then deploys the **API artifact**.

## GitHub Environments

Create three environments in your repository:

**Settings → Environments → New environment**

1. `dev`
2. `qa`
3. `prod` (recommended: enable **Required reviewers** for manual approval)

## Secrets per environment

Configure these secrets on **each** environment (`dev`, `qa`, `prod`):

| Secret | Description | Example |
|--------|-------------|---------|
| `SQL_SERVER` | SQL Server host | `myserver.database.windows.net` |
| `SQL_DATABASE` | Database name | `StudentDb_Dev` / `StudentDb_QA` / `StudentDb_Prod` |
| `SQL_USERNAME` | SQL login | `sqladmin` |
| `SQL_PASSWORD` | SQL password | *(stored securely)* |
| `API_CONNECTION_STRING` | Full ADO.NET connection string for the API | `Server=tcp:...;Database=StudentDb_Dev;User ID=...;Password=...;Encrypt=True;` |
| `AZURE_WEBAPP_NAME` | Azure App Service name | `student-api-dev` |
| `AZURE_CREDENTIALS` | Azure service principal JSON | See below |

### Create Azure service principal

```bash
az ad sp create-for-rbac \
  --name "github-studentmanagement-deploy" \
  --role contributor \
  --scopes /subscriptions/{subscription-id}/resourceGroups/{resource-group} \
  --sdk-auth
```

Copy the JSON output into the `AZURE_CREDENTIALS` secret for each environment (or use a repo-level secret if the same SP is used everywhere).

Grant the service principal **SQL DB Contributor** or run this once per SQL server so deployments can create databases:

```sql
CREATE USER [github-studentmanagement-deploy] FROM EXTERNAL PROVIDER;
ALTER ROLE dbmanager ADD MEMBER [github-studentmanagement-deploy];
```

For existing databases, also grant db_owner on the target database.

## Database automation

Scripts live in `StudentManagement.Database/` and are executed in order via `deploy/deploy-manifest.json`:

1. `001_CreateDatabase.sql` — creates DB on `master` if missing
2. `002_CreateTable.sql` — creates `Students` table
3. `003_StoredProcedures.sql` — creates/alters stored procedures

The pipeline uses `sqlcmd` (installed automatically on Linux runners) through `Deploy-Database.ps1`.

### Manual local deploy

```powershell
cd StudentManagement.Database
./deploy/Deploy-Database.ps1 -Server "localhost" -Database "StudentDb_Dev" -UseTrustedConnection -TrustServerCertificate
```

## API configuration per environment

| Environment | `ASPNETCORE_ENVIRONMENT` | Config file loaded |
|-------------|--------------------------|-------------------|
| Dev | `Development` | `appsettings.Development.json` |
| QA | `QA` | `appsettings.QA.json` |
| Prod | `Production` | `appsettings.Production.json` |

Connection strings are injected at deploy time via `ConnectionStrings__DefaultConnection` — never commit secrets to source control.

## Artifacts

On every push to `dev`, the pipeline uploads:

- `api-release` — published .NET 8 Web API (7-day retention)
- `database-scripts` — SQL scripts + deploy tooling (7-day retention)

Production artifacts are retained for 30 days.

## On-prem / IIS alternative

If you deploy to Windows/IIS instead of Azure App Service, replace the `deploy-api-azure` step with a self-hosted runner and Web Deploy, or download the artifact and run:

```powershell
# Stop site, copy files to inetpub, run database deploy, start site
./StudentManagement.Database/deploy/Deploy-Database.ps1 ...
```

## First-time setup checklist

- [ ] Create `dev`, `qa`, and `prod` GitHub environments
- [ ] Add secrets to each environment
- [ ] Create Azure SQL servers / databases (or allow pipeline to create DB)
- [ ] Create Azure Web Apps for Dev, QA, and Prod
- [ ] Create and push `dev` branch
- [ ] Configure prod environment with required reviewers
- [ ] Merge to `main` when ready for production release
