using Microsoft.Data.SqlClient;

namespace StudentManagementApi.Data;

/// <summary>
/// Factory for creating SQL Server connections.
/// </summary>
public interface ISqlConnectionFactory
{
    /// <summary>
    /// Creates a new SQL connection instance.
    /// </summary>
    SqlConnection CreateConnection();
}
