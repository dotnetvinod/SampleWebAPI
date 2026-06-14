using Microsoft.Data.SqlClient;

namespace StudentManagementApi.Data;

/// <summary>
/// Creates SQL Server connections using the configured connection string.
/// </summary>
public class SqlConnectionFactory : ISqlConnectionFactory
{
    private readonly string _connectionString;

    public SqlConnectionFactory(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("Connection string 'DefaultConnection' is not configured.");
    }

    /// <inheritdoc />
    public SqlConnection CreateConnection() => new(_connectionString);
}
