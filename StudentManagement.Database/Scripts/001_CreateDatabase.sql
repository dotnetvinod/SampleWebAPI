-- Runs against master. Database name is supplied via sqlcmd variable DatabaseName.
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'$(DatabaseName)')
BEGIN
    DECLARE @sql NVARCHAR(256) = N'CREATE DATABASE [' + REPLACE(N'$(DatabaseName)', N']', N']]') + N']';
    EXEC sys.sp_executesql @sql;
END
GO
