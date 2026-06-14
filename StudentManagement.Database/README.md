# Database Scripts — Student Management

SQL Server scripts for the Student Management API. Deployed automatically via GitHub Actions.

## Structure

```
StudentManagement.Database/
├── Scripts/
│   ├── 001_CreateDatabase.sql   # Runs on master
│   ├── 002_CreateTable.sql      # Runs on target DB
│   └── 003_StoredProcedures.sql # Runs on target DB
└── deploy/
    ├── deploy-manifest.json     # Script execution order
    └── Deploy-Database.ps1      # Deployment runner (sqlcmd)
```

## Local deployment

### Windows (integrated auth)

```powershell
./deploy/Deploy-Database.ps1 `
  -Server "localhost" `
  -Database "StudentDb_Dev" `
  -UseTrustedConnection `
  -TrustServerCertificate
```

### Azure SQL (SQL auth)

```powershell
./deploy/Deploy-Database.ps1 `
  -Server "yourserver.database.windows.net" `
  -Database "StudentDb_Dev" `
  -Username "sqladmin" `
  -Password "YourPassword"
```

## Environment database names

| Environment | Suggested database name |
|-------------|---------------------------|
| Dev         | `StudentDb_Dev`           |
| QA          | `StudentDb_QA`            |
| Prod        | `StudentDb_Prod`          |

Connection strings for the API are configured per environment in CI/CD (not stored in source control).
