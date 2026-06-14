using Microsoft.Data.SqlClient;
using StudentManagementApi.Repositories;

namespace StudentManagementApi.UnitOfWork;

/// <summary>
/// Unit of work contract for coordinating repository operations and transactions.
/// </summary>
public interface IUnitOfWork : IDisposable
{
    IStudentRepository StudentRepository { get; }
    Task CommitAsync();
}
