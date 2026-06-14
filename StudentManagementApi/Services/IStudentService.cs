using StudentManagementApi.Models;

namespace StudentManagementApi.Services;

/// <summary>
/// Business logic contract for student operations.
/// </summary>
public interface IStudentService
{
    Task<IEnumerable<Student>> GetAllAsync();
    Task<Student> GetByIdAsync(int id);
    Task<Student> CreateAsync(Student student);
    Task UpdateAsync(int id, Student student);
    Task DeleteAsync(int id);
}
