namespace StudentManagementApi.Models;

/// <summary>
/// Standardized API error response.
/// </summary>
public class ApiErrorResponse
{
    /// <summary>
    /// HTTP status code.
    /// </summary>
    public int StatusCode { get; set; }

    /// <summary>
    /// Short error title or type.
    /// </summary>
    public string Message { get; set; } = string.Empty;

    /// <summary>
    /// Detailed error description.
    /// </summary>
    public string? Details { get; set; }

    /// <summary>
    /// Request trace identifier for correlation.
    /// </summary>
    public string? TraceId { get; set; }
}
