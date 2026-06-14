CREATE OR ALTER PROCEDURE dbo.sp_GetAllStudents
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id,
        FirstName,
        LastName,
        Email,
        Age,
        CreatedDate
    FROM dbo.Students
    ORDER BY Id;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetStudentById
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id,
        FirstName,
        LastName,
        Email,
        Age,
        CreatedDate
    FROM dbo.Students
    WHERE Id = @Id;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_InsertStudent
    @FirstName NVARCHAR(100),
    @LastName NVARCHAR(100),
    @Email NVARCHAR(255),
    @Age INT,
    @CreatedDate DATETIME2,
    @NewId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.Students (FirstName, LastName, Email, Age, CreatedDate)
    VALUES (@FirstName, @LastName, @Email, @Age, @CreatedDate);

    SET @NewId = SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_UpdateStudent
    @Id INT,
    @FirstName NVARCHAR(100),
    @LastName NVARCHAR(100),
    @Email NVARCHAR(255),
    @Age INT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.Students
    SET
        FirstName = @FirstName,
        LastName = @LastName,
        Email = @Email,
        Age = @Age
    WHERE Id = @Id;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_DeleteStudent
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM dbo.Students
    WHERE Id = @Id;
END
GO
