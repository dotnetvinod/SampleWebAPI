using System.Data;
using Microsoft.Data.SqlClient;
using StudentManagementApi.Models;
using StudentManagementApi.UnitOfWork;

namespace StudentManagementApi.Repositories;

/// <summary>
/// ADO.NET repository that executes stored procedures for student operations.
/// </summary>
public class StudentRepository : IStudentRepository
{
    private readonly UnitOfWorkContext _context;

    public StudentRepository(UnitOfWorkContext context)
    {
        _context = context;
    }

    /// <inheritdoc />
    public async Task<IEnumerable<Student>> GetAllAsync()
    {
        await _context.EnsureConnectionOpenAsync();

        var students = new List<Student>();
        await using var command = CreateCommand("sp_GetAllStudents");
        await using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            students.Add(MapStudent(reader));
        }

        return students;
    }

    /// <inheritdoc />
    public async Task<Student?> GetByIdAsync(int id)
    {
        await _context.EnsureConnectionOpenAsync();

        await using var command = CreateCommand("sp_GetStudentById");
        command.Parameters.Add(new SqlParameter("@Id", SqlDbType.Int) { Value = id });

        await using var reader = await command.ExecuteReaderAsync();

        if (!await reader.ReadAsync())
        {
            return null;
        }

        return MapStudent(reader);
    }

    /// <inheritdoc />
    public async Task<int> CreateAsync(Student student)
    {
        await _context.EnsureConnectionOpenAsync();
        _context.BeginTransaction();

        await using var command = CreateCommand("sp_InsertStudent");
        command.Parameters.Add(new SqlParameter("@FirstName", SqlDbType.NVarChar, 100) { Value = student.FirstName });
        command.Parameters.Add(new SqlParameter("@LastName", SqlDbType.NVarChar, 100) { Value = student.LastName });
        command.Parameters.Add(new SqlParameter("@Email", SqlDbType.NVarChar, 255) { Value = student.Email });
        command.Parameters.Add(new SqlParameter("@Age", SqlDbType.Int) { Value = student.Age });
        command.Parameters.Add(new SqlParameter("@CreatedDate", SqlDbType.DateTime2) { Value = student.CreatedDate });

        var newIdParameter = new SqlParameter("@NewId", SqlDbType.Int)
        {
            Direction = ParameterDirection.Output
        };
        command.Parameters.Add(newIdParameter);

        await command.ExecuteNonQueryAsync();

        return (int)newIdParameter.Value;
    }

    /// <inheritdoc />
    public async Task<bool> UpdateAsync(Student student)
    {
        await _context.EnsureConnectionOpenAsync();
        _context.BeginTransaction();

        await using var command = CreateCommand("sp_UpdateStudent");
        command.Parameters.Add(new SqlParameter("@Id", SqlDbType.Int) { Value = student.Id });
        command.Parameters.Add(new SqlParameter("@FirstName", SqlDbType.NVarChar, 100) { Value = student.FirstName });
        command.Parameters.Add(new SqlParameter("@LastName", SqlDbType.NVarChar, 100) { Value = student.LastName });
        command.Parameters.Add(new SqlParameter("@Email", SqlDbType.NVarChar, 255) { Value = student.Email });
        command.Parameters.Add(new SqlParameter("@Age", SqlDbType.Int) { Value = student.Age });

        var rowsAffected = await command.ExecuteNonQueryAsync();
        return rowsAffected > 0;
    }

    /// <inheritdoc />
    public async Task<bool> DeleteAsync(int id)
    {
        await _context.EnsureConnectionOpenAsync();
        _context.BeginTransaction();

        await using var command = CreateCommand("sp_DeleteStudent");
        command.Parameters.Add(new SqlParameter("@Id", SqlDbType.Int) { Value = id });

        var rowsAffected = await command.ExecuteNonQueryAsync();
        return rowsAffected > 0;
    }

    private SqlCommand CreateCommand(string storedProcedureName)
    {
        var command = _context.Connection.CreateCommand();
        command.CommandText = storedProcedureName;
        command.CommandType = CommandType.StoredProcedure;

        if (_context.Transaction is not null)
        {
            command.Transaction = _context.Transaction;
        }

        return command;
    }

    private static Student MapStudent(SqlDataReader reader) => new()
    {
        Id = reader.GetInt32(reader.GetOrdinal("Id")),
        FirstName = reader.GetString(reader.GetOrdinal("FirstName")),
        LastName = reader.GetString(reader.GetOrdinal("LastName")),
        Email = reader.GetString(reader.GetOrdinal("Email")),
        Age = reader.GetInt32(reader.GetOrdinal("Age")),
        CreatedDate = reader.GetDateTime(reader.GetOrdinal("CreatedDate"))
    };
}
