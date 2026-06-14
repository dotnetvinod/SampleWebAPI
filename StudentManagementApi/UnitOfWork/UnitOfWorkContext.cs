using System.Data;
using Microsoft.Data.SqlClient;
using StudentManagementApi.Data;

namespace StudentManagementApi.UnitOfWork;

/// <summary>
/// Shared connection and transaction context for repositories within a unit of work.
/// </summary>
public sealed class UnitOfWorkContext : IAsyncDisposable
{
    private readonly ISqlConnectionFactory _connectionFactory;
    private SqlConnection? _connection;
    private SqlTransaction? _transaction;
    private bool _disposed;

    public UnitOfWorkContext(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public SqlConnection Connection => _connection ??= _connectionFactory.CreateConnection();

    public SqlTransaction? Transaction => _transaction;

    public async Task EnsureConnectionOpenAsync()
    {
        ObjectDisposedException.ThrowIf(_disposed, this);

        if (Connection.State != ConnectionState.Open)
        {
            await Connection.OpenAsync();
        }
    }

    public void BeginTransaction()
    {
        ObjectDisposedException.ThrowIf(_disposed, this);

        if (_transaction is null)
        {
            _transaction = Connection.BeginTransaction();
        }
    }

    public async Task CommitAsync()
    {
        ObjectDisposedException.ThrowIf(_disposed, this);

        if (_transaction is not null)
        {
            await _transaction.CommitAsync();
            await _transaction.DisposeAsync();
            _transaction = null;
        }
    }

    public async ValueTask DisposeAsync()
    {
        if (_disposed)
        {
            return;
        }

        if (_transaction is not null)
        {
            await _transaction.RollbackAsync();
            await _transaction.DisposeAsync();
            _transaction = null;
        }

        if (_connection is not null)
        {
            await _connection.DisposeAsync();
            _connection = null;
        }

        _disposed = true;
    }
}
