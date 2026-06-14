using StudentManagementApi.Models;
using StudentManagementApi.Models.Exceptions;
using StudentManagementApi.UnitOfWork;

namespace StudentManagementApi.Services;

/// <summary>
/// Implements student business rules and orchestrates repository operations.
/// </summary>
public class StudentService : IStudentService
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<StudentService> _logger;

    public StudentService(IUnitOfWork unitOfWork, ILogger<StudentService> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task<IEnumerable<Student>> GetAllAsync()
    {
        _logger.LogInformation("Retrieving all students.");
        return await _unitOfWork.StudentRepository.GetAllAsync();
    }

    /// <inheritdoc />
    public async Task<Student> GetByIdAsync(int id)
    {
        _logger.LogInformation("Retrieving student with Id {StudentId}.", id);

        var student = await _unitOfWork.StudentRepository.GetByIdAsync(id);
        if (student is null)
        {
            throw new NotFoundException($"Student with Id {id} was not found.");
        }

        return student;
    }

    /// <inheritdoc />
    public async Task<Student> CreateAsync(Student student)
    {
        _logger.LogInformation("Creating student with email {Email}.", student.Email);

        student.CreatedDate = DateTime.UtcNow;

        var newId = await _unitOfWork.StudentRepository.CreateAsync(student);
        await _unitOfWork.CommitAsync();

        student.Id = newId;
        return student;
    }

    /// <inheritdoc />
    public async Task UpdateAsync(int id, Student student)
    {
        _logger.LogInformation("Updating student with Id {StudentId}.", id);

        var existing = await _unitOfWork.StudentRepository.GetByIdAsync(id);
        if (existing is null)
        {
            throw new NotFoundException($"Student with Id {id} was not found.");
        }

        student.Id = id;
        student.CreatedDate = existing.CreatedDate;

        var updated = await _unitOfWork.StudentRepository.UpdateAsync(student);
        if (!updated)
        {
            throw new NotFoundException($"Student with Id {id} was not found.");
        }

        await _unitOfWork.CommitAsync();
    }

    /// <inheritdoc />
    public async Task DeleteAsync(int id)
    {
        _logger.LogInformation("Deleting student with Id {StudentId}.", id);

        var deleted = await _unitOfWork.StudentRepository.DeleteAsync(id);
        if (!deleted)
        {
            throw new NotFoundException($"Student with Id {id} was not found.");
        }

        await _unitOfWork.CommitAsync();
    }
}
