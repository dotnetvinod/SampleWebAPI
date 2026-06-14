-- Runs against the target database (sqlcmd -d).
IF NOT EXISTS (
    SELECT 1
    FROM sys.tables
    WHERE name = N'Students' AND schema_id = SCHEMA_ID(N'dbo')
)
BEGIN
    CREATE TABLE dbo.Students
    (
        Id INT IDENTITY(1, 1) NOT NULL,
        FirstName NVARCHAR(100) NOT NULL,
        LastName NVARCHAR(100) NOT NULL,
        Email NVARCHAR(255) NOT NULL,
        Age INT NOT NULL,
        CreatedDate DATETIME2 NOT NULL,
        CONSTRAINT PK_Students PRIMARY KEY CLUSTERED (Id ASC),
        CONSTRAINT UQ_Students_Email UNIQUE (Email),
        CONSTRAINT CK_Students_Age CHECK (Age BETWEEN 1 AND 150)
    );
END
GO
