using Microsoft.AspNetCore.Mvc;
using StudentManagementApi.Models;
using StudentManagementApi.Services;

namespace StudentManagementApi.Controllers;

/// <summary>
/// API endpoints for managing students.
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Produces("application/json")]
public class StudentController : ControllerBase
{
    private readonly IStudentService _studentService;
    private readonly ILogger<StudentController> _logger;

    public StudentController(IStudentService studentService, ILogger<StudentController> logger)
    {
        _studentService = studentService;
        _logger = logger;
    }

    /// <summary>
    /// Gets all students.
    /// </summary>
    /// <returns>A list of students.</returns>
    /// <response code="200">Returns the list of students.</response>
    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<Student>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<Student>>> GetAll()
    {
        var students = await _studentService.GetAllAsync();
        return Ok(students);
    }

    /// <summary>
    /// Gets a student by identifier.
    /// </summary>
    /// <param name="id">Student identifier.</param>
    /// <returns>The student record.</returns>
    /// <response code="200">Returns the requested student.</response>
    /// <response code="404">Student was not found.</response>
    [HttpGet("{id:int}")]
    [ProducesResponseType(typeof(Student), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiErrorResponse), StatusCodes.Status404NotFound)]
    public async Task<ActionResult<Student>> GetById(int id)
    {
        var student = await _studentService.GetByIdAsync(id);
        return Ok(student);
    }

    /// <summary>
    /// Creates a new student.
    /// </summary>
    /// <param name="student">Student data.</param>
    /// <returns>The created student.</returns>
    /// <response code="201">Student was created successfully.</response>
    /// <response code="400">Validation failed.</response>
    [HttpPost]
    [ProducesResponseType(typeof(Student), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ApiErrorResponse), StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<Student>> Create([FromBody] Student student)
    {
        if (!ModelState.IsValid)
        {
            return ValidationProblem(ModelState);
        }

        var created = await _studentService.CreateAsync(student);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    /// <summary>
    /// Updates an existing student.
    /// </summary>
    /// <param name="id">Student identifier.</param>
    /// <param name="student">Updated student data.</param>
    /// <response code="204">Student was updated successfully.</response>
    /// <response code="400">Validation failed.</response>
    /// <response code="404">Student was not found.</response>
    [HttpPut("{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(typeof(ApiErrorResponse), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ApiErrorResponse), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Update(int id, [FromBody] Student student)
    {
        if (!ModelState.IsValid)
        {
            return ValidationProblem(ModelState);
        }

        await _studentService.UpdateAsync(id, student);
        return NoContent();
    }

    /// <summary>
    /// Deletes a student.
    /// </summary>
    /// <param name="id">Student identifier.</param>
    /// <response code="204">Student was deleted successfully.</response>
    /// <response code="404">Student was not found.</response>
    [HttpDelete("{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(typeof(ApiErrorResponse), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Delete(int id)
    {
        await _studentService.DeleteAsync(id);
        return NoContent();
    }
}
