using Microsoft.Extensions.Logging;
using Moq;
using StudentManagementApi.Models;
using StudentManagementApi.Models.Exceptions;
using StudentManagementApi.Repositories;
using StudentManagementApi.Services;
using StudentManagementApi.UnitOfWork;

namespace StudentManagementApi.Tests.Services;

public class StudentServiceTests
{
    private readonly Mock<IUnitOfWork> _unitOfWorkMock;
    private readonly Mock<IStudentRepository> _studentRepositoryMock;
    private readonly Mock<ILogger<StudentService>> _loggerMock;
    private readonly StudentService _sut;

    public StudentServiceTests()
    {
        _unitOfWorkMock = new Mock<IUnitOfWork>();
        _studentRepositoryMock = new Mock<IStudentRepository>();
        _loggerMock = new Mock<ILogger<StudentService>>();

        _unitOfWorkMock.Setup(u => u.StudentRepository).Returns(_studentRepositoryMock.Object);

        _sut = new StudentService(_unitOfWorkMock.Object, _loggerMock.Object);
    }

    [Fact]
    public async Task GetAllAsync_ReturnsAllStudents()
    {
        var students = new List<Student>
        {
            new() { Id = 1, FirstName = "John", LastName = "Doe", Email = "john@example.com", Age = 20, CreatedDate = DateTime.UtcNow }
        };

        _studentRepositoryMock.Setup(r => r.GetAllAsync()).ReturnsAsync(students);

        var result = await _sut.GetAllAsync();

        Assert.Single(result);
        Assert.Equal("John", result.First().FirstName);
    }

    [Fact]
    public async Task GetByIdAsync_WhenStudentExists_ReturnsStudent()
    {
        var student = new Student
        {
            Id = 1,
            FirstName = "Jane",
            LastName = "Smith",
            Email = "jane@example.com",
            Age = 22,
            CreatedDate = DateTime.UtcNow
        };

        _studentRepositoryMock.Setup(r => r.GetByIdAsync(1)).ReturnsAsync(student);

        var result = await _sut.GetByIdAsync(1);

        Assert.Equal(student.Email, result.Email);
    }

    [Fact]
    public async Task GetByIdAsync_WhenStudentNotFound_ThrowsNotFoundException()
    {
        _studentRepositoryMock.Setup(r => r.GetByIdAsync(99)).ReturnsAsync((Student?)null);

        await Assert.ThrowsAsync<NotFoundException>(() => _sut.GetByIdAsync(99));
    }

    [Fact]
    public async Task CreateAsync_SetsCreatedDateAndCommitsTransaction()
    {
        var student = new Student
        {
            FirstName = "Alice",
            LastName = "Brown",
            Email = "alice@example.com",
            Age = 19
        };

        _studentRepositoryMock.Setup(r => r.CreateAsync(It.IsAny<Student>())).ReturnsAsync(5);
        _unitOfWorkMock.Setup(u => u.CommitAsync()).Returns(Task.CompletedTask);

        var result = await _sut.CreateAsync(student);

        Assert.Equal(5, result.Id);
        Assert.NotEqual(default, result.CreatedDate);
        _unitOfWorkMock.Verify(u => u.CommitAsync(), Times.Once);
    }

    [Fact]
    public async Task UpdateAsync_WhenStudentExists_UpdatesAndCommits()
    {
        var existing = new Student
        {
            Id = 1,
            FirstName = "Old",
            LastName = "Name",
            Email = "old@example.com",
            Age = 20,
            CreatedDate = DateTime.UtcNow.AddDays(-1)
        };

        var updated = new Student
        {
            FirstName = "New",
            LastName = "Name",
            Email = "new@example.com",
            Age = 21
        };

        _studentRepositoryMock.Setup(r => r.GetByIdAsync(1)).ReturnsAsync(existing);
        _studentRepositoryMock.Setup(r => r.UpdateAsync(It.IsAny<Student>())).ReturnsAsync(true);
        _unitOfWorkMock.Setup(u => u.CommitAsync()).Returns(Task.CompletedTask);

        await _sut.UpdateAsync(1, updated);

        _studentRepositoryMock.Verify(r => r.UpdateAsync(It.Is<Student>(s =>
            s.Id == 1 &&
            s.CreatedDate == existing.CreatedDate &&
            s.Email == "new@example.com")), Times.Once);
        _unitOfWorkMock.Verify(u => u.CommitAsync(), Times.Once);
    }

    [Fact]
    public async Task UpdateAsync_WhenStudentNotFound_ThrowsNotFoundException()
    {
        _studentRepositoryMock.Setup(r => r.GetByIdAsync(99)).ReturnsAsync((Student?)null);

        await Assert.ThrowsAsync<NotFoundException>(() =>
            _sut.UpdateAsync(99, new Student { FirstName = "A", LastName = "B", Email = "a@b.com", Age = 20 }));
    }

    [Fact]
    public async Task DeleteAsync_WhenStudentExists_DeletesAndCommits()
    {
        _studentRepositoryMock.Setup(r => r.DeleteAsync(1)).ReturnsAsync(true);
        _unitOfWorkMock.Setup(u => u.CommitAsync()).Returns(Task.CompletedTask);

        await _sut.DeleteAsync(1);

        _studentRepositoryMock.Verify(r => r.DeleteAsync(1), Times.Once);
        _unitOfWorkMock.Verify(u => u.CommitAsync(), Times.Once);
    }

    [Fact]
    public async Task DeleteAsync_WhenStudentNotFound_ThrowsNotFoundException()
    {
        _studentRepositoryMock.Setup(r => r.DeleteAsync(99)).ReturnsAsync(false);

        await Assert.ThrowsAsync<NotFoundException>(() => _sut.DeleteAsync(99));
    }
}
