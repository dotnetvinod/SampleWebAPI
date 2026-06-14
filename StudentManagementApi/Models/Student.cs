using System.ComponentModel.DataAnnotations;

namespace StudentManagementApi.Models;

/// <summary>
/// Represents a student entity in the system.
/// </summary>
public class Student
{
    /// <summary>
    /// Unique identifier for the student.
    /// </summary>
    public int Id { get; set; }

    /// <summary>
    /// Student's first name.
    /// </summary>
    [Required(ErrorMessage = "First name is required.")]
    [StringLength(100, MinimumLength = 1, ErrorMessage = "First name must be between 1 and 100 characters.")]
    public string FirstName { get; set; } = string.Empty;

    /// <summary>
    /// Student's last name.
    /// </summary>
    [Required(ErrorMessage = "Last name is required.")]
    [StringLength(100, MinimumLength = 1, ErrorMessage = "Last name must be between 1 and 100 characters.")]
    public string LastName { get; set; } = string.Empty;

    /// <summary>
    /// Student's email address.
    /// </summary>
    [Required(ErrorMessage = "Email is required.")]
    [EmailAddress(ErrorMessage = "A valid email address is required.")]
    [StringLength(255)]
    public string Email { get; set; } = string.Empty;

    /// <summary>
    /// Student's age.
    /// </summary>
    [Range(1, 150, ErrorMessage = "Age must be between 1 and 150.")]
    public int Age { get; set; }

    /// <summary>
    /// Date and time when the student record was created.
    /// </summary>
    public DateTime CreatedDate { get; set; }
}
