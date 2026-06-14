using StudentManagementApi.Models;

namespace StudentManagementApi.Repositories;

/// <summary>
/// Data access contract for student CRUD operations.
/// </summary>
public interface IStudentRepository
{
    Task<IEnumerable<Student>> GetAllAsync();
    Task<Student?> GetByIdAsync(int id);
    Task<int> CreateAsync(Student student);
    Task<bool> UpdateAsync(Student student);
    Task<bool> DeleteAsync(int id);
}
