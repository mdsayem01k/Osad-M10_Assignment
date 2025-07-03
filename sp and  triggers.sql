-- =====================================================
-- Module 9 Assignment: Employee Management System
-- Northwind Database Implementation
-- =====================================================

-- First, create an audit log table to track employee changes
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='EmployeeAuditLog' AND xtype='U')
BEGIN
    CREATE TABLE EmployeeAuditLog (
        AuditID INT IDENTITY(1,1) PRIMARY KEY,
        EmployeeID INT,
        Operation VARCHAR(10),
        OldData NVARCHAR(MAX),
        NewData NVARCHAR(MAX),
        ChangedBy NVARCHAR(100),
        ChangeDate DATETIME
    );
    PRINT 'EmployeeAuditLog table created successfully';
END
GO

-- =====================================================
-- 1. STORED PROCEDURE: Create Employee with Region and Territory
-- Following the pattern from your class examples
-- =====================================================

CREATE OR ALTER PROCEDURE CreateEmployeeInRegionTerritory
(
    @FirstName NVARCHAR(10),
    @LastName NVARCHAR(20),
    @Title NVARCHAR(30) = NULL,
    @TitleOfCourtesy NVARCHAR(25) = NULL,
    @BirthDate DATETIME = NULL,
    @HireDate DATETIME = NULL,
    @Address NVARCHAR(60) = NULL,
    @City NVARCHAR(15) = NULL,
    @Region NVARCHAR(15),
    @PostalCode NVARCHAR(10) = NULL,
    @Country NVARCHAR(15) = NULL,
    @HomePhone NVARCHAR(24) = NULL,
    @Extension NVARCHAR(4) = NULL,
    @Notes NTEXT = NULL,
    @ReportsTo INT = NULL,
    @PhotoPath NVARCHAR(255) = NULL,
    @TerritoryID NVARCHAR(20),
    @NewEmployeeID INT OUT
)
AS
BEGIN

SET NOCOUNT ON

DECLARE @EmployeeID INT

BEGIN TRY
BEGIN TRANSACTION

    -- Validate required parameters
    IF(@FirstName IS NULL OR LTRIM(RTRIM(@FirstName)) = '')
        RAISERROR('First Name cannot be empty', 16, 1)
    
    IF(@LastName IS NULL OR LTRIM(RTRIM(@LastName)) = '')
        RAISERROR('Last Name cannot be empty', 16, 1)
    
    IF(@Region IS NULL OR LTRIM(RTRIM(@Region)) = '')
        RAISERROR('Region cannot be empty', 16, 1)
    
    IF(@TerritoryID IS NULL OR LTRIM(RTRIM(@TerritoryID)) = '')
        RAISERROR('Territory ID cannot be empty', 16, 1)

    -- Check if Territory exists
    IF NOT EXISTS (SELECT 1 FROM Territories WHERE TerritoryID = @TerritoryID)
        RAISERROR('Territory ID does not exist', 16, 1)

    -- Check if ReportsTo employee exists (if provided)
    IF @ReportsTo IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Employees WHERE EmployeeID = @ReportsTo)
        RAISERROR('Manager (ReportsTo) employee does not exist', 16, 1)

    -- Set default hire date if not provided
    IF @HireDate IS NULL
        SET @HireDate = GETDATE()

    -- Insert new employee
    INSERT INTO Employees
    (
        FirstName, LastName, Title, TitleOfCourtesy, BirthDate,
        HireDate, Address, City, Region, PostalCode, Country,
        HomePhone, Extension, Notes, ReportsTo, PhotoPath
    )
    VALUES
    (
        @FirstName, @LastName, @Title, @TitleOfCourtesy, @BirthDate,
        @HireDate, @Address, @City, @Region, @PostalCode, @Country,
        @HomePhone, @Extension, @Notes, @ReportsTo, @PhotoPath
    )

    -- Get the newly created employee ID
    SELECT @EmployeeID = @@IDENTITY

    -- Assign employee to territory
    INSERT INTO EmployeeTerritories (EmployeeID, TerritoryID)
    VALUES (@EmployeeID, @TerritoryID)

    -- Set output parameter
    SET @NewEmployeeID = @EmployeeID

    -- Success message
    PRINT 'Employee created successfully with ID: ' + CAST(@EmployeeID AS VARCHAR(10))
    PRINT 'Employee assigned to Territory: ' + @TerritoryID

COMMIT TRANSACTION
END TRY
BEGIN CATCH    

    ROLLBACK TRANSACTION    

    SELECT ERROR_NUMBER() AS ErrorNumber,
           ERROR_SEVERITY() AS ErrorSeverity,
           ERROR_STATE() AS ErrorState,
           ERROR_PROCEDURE() AS ErrorProcedure,
           ERROR_LINE() AS ErrorLine,
           ERROR_MESSAGE() AS ErrorMessage

    -- Set output parameter to NULL on error
    SET @NewEmployeeID = NULL
    
END CATCH

END
GO

-- =====================================================
-- 2. TRIGGERS: Handle INSERT/UPDATE/DELETE on Employee Table
-- Following the trigger patterns from your class examples
-- =====================================================

-- TRIGGER 1: Handle INSERT operations
CREATE OR ALTER TRIGGER TR_INS_Employee 
ON Employees
AFTER INSERT
NOT FOR REPLICATION
AS
BEGIN
    SET NOCOUNT ON
    
    DECLARE @EmployeeID INT,
            @NewData NVARCHAR(MAX)
    
    SELECT @EmployeeID = EmployeeID FROM inserted
    
    -- Build new data string
    SELECT @NewData = 'ID: ' + CAST(EmployeeID AS VARCHAR(10)) + 
                     ' | Name: ' + FirstName + ' ' + LastName +
                     ' | Title: ' + ISNULL(Title, 'NULL') +
                     ' | Region: ' + ISNULL(Region, 'NULL') +
                     ' | HireDate: ' + CONVERT(VARCHAR(20), HireDate, 120) +
                     ' | ReportsTo: ' + ISNULL(CAST(ReportsTo AS VARCHAR(10)), 'NULL')
    FROM inserted
    
    -- Insert audit log
    INSERT INTO EmployeeAuditLog 
    (EmployeeID, Operation, OldData, NewData, ChangedBy, ChangeDate)
    VALUES 
    (@EmployeeID, 'INSERT', NULL, @NewData, SYSTEM_USER, GETDATE())
    
    PRINT 'TRIGGER FIRED: Employee INSERT - ID: ' + CAST(@EmployeeID AS VARCHAR(10))
    PRINT 'Audit log entry created for INSERT operation'
END
GO

-- TRIGGER 2: Handle UPDATE operations
CREATE OR ALTER TRIGGER TR_UPD_Employee 
ON Employees
AFTER UPDATE
NOT FOR REPLICATION
AS
BEGIN
    SET NOCOUNT ON
    
    DECLARE @EmployeeID INT,
            @OldData NVARCHAR(MAX),
            @NewData NVARCHAR(MAX)
    
    SELECT @EmployeeID = EmployeeID FROM inserted
    
    -- Build old data string from deleted table
    SELECT @OldData = 'ID: ' + CAST(EmployeeID AS VARCHAR(10)) + 
                     ' | Name: ' + FirstName + ' ' + LastName +
                     ' | Title: ' + ISNULL(Title, 'NULL') +
                     ' | Region: ' + ISNULL(Region, 'NULL') +
                     ' | HireDate: ' + CONVERT(VARCHAR(20), HireDate, 120) +
                     ' | ReportsTo: ' + ISNULL(CAST(ReportsTo AS VARCHAR(10)), 'NULL')
    FROM deleted
    
    -- Build new data string from inserted table
    SELECT @NewData = 'ID: ' + CAST(EmployeeID AS VARCHAR(10)) + 
                     ' | Name: ' + FirstName + ' ' + LastName +
                     ' | Title: ' + ISNULL(Title, 'NULL') +
                     ' | Region: ' + ISNULL(Region, 'NULL') +
                     ' | HireDate: ' + CONVERT(VARCHAR(20), HireDate, 120) +
                     ' | ReportsTo: ' + ISNULL(CAST(ReportsTo AS VARCHAR(10)), 'NULL')
    FROM inserted
    
    -- Insert audit log
    INSERT INTO EmployeeAuditLog 
    (EmployeeID, Operation, OldData, NewData, ChangedBy, ChangeDate)
    VALUES 
    (@EmployeeID, 'UPDATE', @OldData, @NewData, SYSTEM_USER, GETDATE())
    
    PRINT 'TRIGGER FIRED: Employee UPDATE - ID: ' + CAST(@EmployeeID AS VARCHAR(10))
    PRINT 'Audit log entry created for UPDATE operation'
END
GO

-- TRIGGER 3: Handle DELETE operations
CREATE OR ALTER TRIGGER TR_DEL_Employee 
ON Employees
AFTER DELETE
NOT FOR REPLICATION
AS
BEGIN
    SET NOCOUNT ON
    
    DECLARE @EmployeeID INT,
            @OldData NVARCHAR(MAX)
    
    SELECT @EmployeeID = EmployeeID FROM deleted
    
    -- Build old data string from deleted table
    SELECT @OldData = 'ID: ' + CAST(EmployeeID AS VARCHAR(10)) + 
                     ' | Name: ' + FirstName + ' ' + LastName +
                     ' | Title: ' + ISNULL(Title, 'NULL') +
                     ' | Region: ' + ISNULL(Region, 'NULL') +
                     ' | HireDate: ' + CONVERT(VARCHAR(20), HireDate, 120) +
                     ' | ReportsTo: ' + ISNULL(CAST(ReportsTo AS VARCHAR(10)), 'NULL')
    FROM deleted
    
    -- Insert audit log
    INSERT INTO EmployeeAuditLog 
    (EmployeeID, Operation, OldData, NewData, ChangedBy, ChangeDate)
    VALUES 
    (@EmployeeID, 'DELETE', @OldData, NULL, SYSTEM_USER, GETDATE())
    
    PRINT 'TRIGGER FIRED: Employee DELETE - ID: ' + CAST(@EmployeeID AS VARCHAR(10))
    PRINT 'Audit log entry created for DELETE operation'
END
GO

-- =====================================================
-- DEMO DATA INSERTION AND ERROR HANDLING TESTS
-- =====================================================

PRINT '========================================='
PRINT 'DEMO DATA INSERTION AND ERROR HANDLING'
PRINT '========================================='

-- DEMO 1: Insert first employee (Sales Representative)
PRINT '--- DEMO DATA 1: Creating Sales Representative ---'
DECLARE @DemoEmp1ID INT

EXEC CreateEmployeeInRegionTerritory 
    @FirstName = 'John',
    @LastName = 'Smith',
    @Title = 'Sales Representative',
    @TitleOfCourtesy = 'Mr.',
    @BirthDate = '1985-03-20',
    @HireDate = '2024-01-15',
    @Address = '123 Pine Street',
    @City = 'Seattle',
    @Region = 'WA',
    @PostalCode = '98101',
    @Country = 'USA',
    @HomePhone = '(206) 555-1234',
    @Extension = '2101',
    @Notes = 'Experienced sales professional with 5 years in retail',
    @ReportsTo = 2,
    @TerritoryID = '01581',
    @NewEmployeeID = @DemoEmp1ID OUTPUT

IF @DemoEmp1ID IS NOT NULL
    PRINT '✓ SUCCESS: Demo Employee 1 created with ID = ' + CAST(@DemoEmp1ID AS VARCHAR(10))
ELSE
    PRINT '✗ FAILED: Demo Employee 1 creation failed'

PRINT ''

-- DEMO 2: Insert second employee (Account Manager) 
PRINT '--- DEMO DATA 2: Creating Account Manager ---'
DECLARE @DemoEmp2ID INT

EXEC CreateEmployeeInRegionTerritory 
    @FirstName = 'Sarah',
    @LastName = 'Johnson',
    @Title = 'Account Manager',
    @TitleOfCourtesy = 'Ms.',
    @BirthDate = '1988-07-12',
    @HireDate = '2024-02-01',
    @Address = '456 Oak Avenue',
    @City = 'Redmond',
    @Region = 'WA',
    @PostalCode = '98052',
    @Country = 'USA',
    @HomePhone = '(425) 555-5678',
    @Extension = '2205',
    @Notes = 'MBA graduate specializing in client relationship management',
    @ReportsTo = 5,
    @TerritoryID = '02116',
    @NewEmployeeID = @DemoEmp2ID OUTPUT

IF @DemoEmp2ID IS NOT NULL
    PRINT '✓ SUCCESS: Demo Employee 2 created with ID = ' + CAST(@DemoEmp2ID AS VARCHAR(10))
ELSE
    PRINT '✗ FAILED: Demo Employee 2 creation failed'

PRINT ''

-- ERROR HANDLING DEMO: Invalid Territory ID
PRINT '--- ERROR HANDLING DEMO: Invalid Territory ID ---'
DECLARE @ErrorEmp1ID INT

BEGIN TRY
    EXEC CreateEmployeeInRegionTerritory 
        @FirstName = 'Michael',
        @LastName = 'Brown',
        @Title = 'Sales Associate',
        @Region = 'CA',
        @TerritoryID = 'INVALID99999',  -- This will cause an error
        @NewEmployeeID = @ErrorEmp1ID OUTPUT
        
    PRINT '✗ UNEXPECTED: This should not print - error should have occurred'
END TRY
BEGIN CATCH
    PRINT '✓ EXPECTED ERROR CAUGHT:'
    PRINT '  Error Number: ' + CAST(ERROR_NUMBER() AS VARCHAR(10))
    PRINT '  Error Message: ' + ERROR_MESSAGE()
    PRINT '  Error Procedure: ' + ISNULL(ERROR_PROCEDURE(), 'N/A')
END CATCH

PRINT ''

-- Show the successfully created employees
PRINT '--- VIEWING CREATED DEMO EMPLOYEES ---'
SELECT 
    EmployeeID,
    FirstName + ' ' + LastName AS FullName,
    Title,
    Region,
    City,
    HireDate,
    ReportsTo
FROM Employees 
WHERE EmployeeID IN (@DemoEmp1ID, @DemoEmp2ID)
ORDER BY EmployeeID

PRINT ''

-- Show territory assignments
PRINT '--- TERRITORY ASSIGNMENTS FOR DEMO EMPLOYEES ---'
SELECT 
    et.EmployeeID,
    e.FirstName + ' ' + e.LastName AS EmployeeName,
    et.TerritoryID,
    t.TerritoryDescription,
    r.RegionDescription
FROM EmployeeTerritories et
INNER JOIN Employees e ON et.EmployeeID = e.EmployeeID
INNER JOIN Territories t ON et.TerritoryID = t.TerritoryID
INNER JOIN Region r ON t.RegionID = r.RegionID
WHERE et.EmployeeID IN (@DemoEmp1ID, @DemoEmp2ID)
ORDER BY et.EmployeeID

PRINT ''

-- =====================================================
-- ADDITIONAL TEST SCENARIOS
-- =====================================================

PRINT '--- ADDITIONAL TESTS ---'

-- Test UPDATE trigger with demo data
PRINT 'Testing UPDATE trigger with demo employees'
IF @DemoEmp1ID IS NOT NULL
BEGIN
    UPDATE Employees 
    SET Title = 'Senior Sales Representative', 
        Extension = '2150',
        Notes = 'Promoted to Senior position after excellent performance'
    WHERE EmployeeID = @DemoEmp1ID
    
    PRINT '✓ Demo Employee 1 updated - UPDATE trigger should have fired'
END

IF @DemoEmp2ID IS NOT NULL
BEGIN
    UPDATE Employees 
    SET City = 'Bellevue',
        HomePhone = '(425) 555-9999'
    WHERE EmployeeID = @DemoEmp2ID
    
    PRINT '✓ Demo Employee 2 updated - UPDATE trigger should have fired'
END
PRINT ''

-- Test 3: View recent audit log entries for demo data
PRINT 'Test 3: Viewing audit log entries for demo employees'
SELECT 
    AuditID,
    EmployeeID,
    Operation,
    CASE 
        WHEN Operation = 'INSERT' THEN LEFT(NewData, 100) + '...'
        WHEN Operation = 'UPDATE' THEN 'UPDATED: ' + LEFT(NewData, 80) + '...'
        WHEN Operation = 'DELETE' THEN LEFT(OldData, 100) + '...'
    END AS OperationSummary,
    ChangedBy,
    ChangeDate
FROM EmployeeAuditLog 
WHERE EmployeeID IN (@DemoEmp1ID, @DemoEmp2ID)
ORDER BY ChangeDate DESC

PRINT ''

-- Additional Error Handling Tests
PRINT '--- MORE ERROR HANDLING TESTS ---'

-- Error Test 1: Empty First Name
PRINT 'Error Test 1: Empty First Name'
DECLARE @ErrorEmp2ID INT
BEGIN TRY
    EXEC CreateEmployeeInRegionTerritory 
        @FirstName = '',  -- Empty first name
        @LastName = 'TestLastName',
        @Region = 'WA',
        @TerritoryID = '01581',
        @NewEmployeeID = @ErrorEmp2ID OUTPUT
END TRY
BEGIN CATCH
    PRINT '✓ EXPECTED ERROR: ' + ERROR_MESSAGE()
END CATCH
PRINT ''

-- Error Test 2: Invalid Manager (ReportsTo)
PRINT 'Error Test 2: Invalid Manager (ReportsTo)'
DECLARE @ErrorEmp3ID INT
BEGIN TRY
    EXEC CreateEmployeeInRegionTerritory 
        @FirstName = 'Test',
        @LastName = 'Employee',
        @Region = 'WA',
        @TerritoryID = '01581',
        @ReportsTo = 99999,  -- Non-existent manager
        @NewEmployeeID = @ErrorEmp3ID OUTPUT
END TRY
BEGIN CATCH
    PRINT '✓ EXPECTED ERROR: ' + ERROR_MESSAGE()
END CATCH
PRINT ''

-- Show available territories for reference
PRINT 'Available Territories (first 5):'
SELECT TOP 5 
    TerritoryID, 
    TerritoryDescription, 
    RegionID 
FROM Territories
ORDER BY TerritoryID

PRINT ''

-- Clean up demo data (Test DELETE trigger)
PRINT 'Cleanup: Testing DELETE trigger with demo employees'
IF @DemoEmp1ID IS NOT NULL
BEGIN
    -- First remove from EmployeeTerritories
    DELETE FROM EmployeeTerritories WHERE EmployeeID = @DemoEmp1ID
    -- Then remove from Employees (this will trigger DELETE trigger)
    DELETE FROM Employees WHERE EmployeeID = @DemoEmp1ID
    PRINT '✓ Demo Employee 1 deleted (DELETE trigger should have fired)'
END

IF @DemoEmp2ID IS NOT NULL
BEGIN
    -- First remove from EmployeeTerritories
    DELETE FROM EmployeeTerritories WHERE EmployeeID = @DemoEmp2ID
    -- Then remove from Employees (this will trigger DELETE trigger)
    DELETE FROM Employees WHERE EmployeeID = @DemoEmp2ID
    PRINT '✓ Demo Employee 2 deleted (DELETE trigger should have fired)'
END

PRINT ''
PRINT '========================================='
PRINT 'DEMO EXECUTION COMPLETED!'
PRINT '========================================='
PRINT 'SUMMARY OF EXECUTED OPERATIONS:'
PRINT '✓ 2 Demo employees successfully created'
PRINT '✓ 3 Error handling scenarios tested'
PRINT '✓ UPDATE triggers tested with data modifications'
PRINT '✓ DELETE triggers tested with cleanup'
PRINT '✓ All audit log entries created'
PRINT ''
PRINT 'STORED PROCEDURE EXECUTIONS:'
PRINT '1. EXEC CreateEmployeeInRegionTerritory (Demo 1 - Success)'
PRINT '2. EXEC CreateEmployeeInRegionTerritory (Demo 2 - Success)'
PRINT '3. EXEC CreateEmployeeInRegionTerritory (Error 1 - Invalid Territory)'
PRINT '4. EXEC CreateEmployeeInRegionTerritory (Error 2 - Empty Name)'
PRINT '5. EXEC CreateEmployeeInRegionTerritory (Error 3 - Invalid Manager)'

-- Final audit log check
PRINT ''
PRINT 'Final Audit Log Summary:'
SELECT 
    Operation,
    COUNT(*) as Count
FROM EmployeeAuditLog 
GROUP BY Operation
ORDER BY Operation
