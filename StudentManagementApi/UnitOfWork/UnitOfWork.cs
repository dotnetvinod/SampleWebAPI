using StudentManagementApi.Repositories;

namespace StudentManagementApi.UnitOfWork;

/// <summary>
/// Coordinates repository access and transaction commits for a single request scope.
/// </summary>
public class UnitOfWork : IUnitOfWork
{
    private readonly UnitOfWorkContext _context;
    private bool _disposed;

    public UnitOfWork(UnitOfWorkContext context, IStudentRepository studentRepository)
    {
        _context = context;
        StudentRepository = studentRepository;
    }

    /// <inheritdoc />
    public IStudentRepository StudentRepository { get; }

    /// <inheritdoc />
    public async Task CommitAsync()
    {
        await _context.CommitAsync();
    }

    /// <inheritdoc />
    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _context.DisposeAsync().AsTask().GetAwaiter().GetResult();
        _disposed = true;
    }
}
