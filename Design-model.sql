-- 2. Tạo các bảng Dimension (Bảng Chiều)

-- 2.1 Bảng Dim_Product
CREATE TABLE Dim_Product (
    ProductKey INT IDENTITY(1,1) PRIMARY KEY,
    Category NVARCHAR(100),
    [Type] NVARCHAR(100), -- Dùng ngoặc vuông vì Type là từ khóa của SQL
    Detail NVARCHAR(255)
);

-- 2.2 Bảng Dim_Store
CREATE TABLE Dim_Store (
    StoreKey INT IDENTITY(1,1) PRIMARY KEY,
    StoreLocation NVARCHAR(255)
);

-- 2.3 Bảng Dim_User
CREATE TABLE Dim_User (
    UserKey INT IDENTITY(1,1) PRIMARY KEY,
    EmailUser VARCHAR(255),
    UserName NVARCHAR(255),
    UserGender NVARCHAR(50),
    UserBirthDate DATE
);

-- 2.4 Bảng Dim_Date
CREATE TABLE Dim_Date (
    DateKey INT PRIMARY KEY, -- Dạng YYYYMMDD, KHÔNG dùng IDENTITY
    FullDate DATE,
    [Day] INT,
    [Month] INT,
    [Year] INT
);

-- 2.5 Bảng Dim_Time
CREATE TABLE Dim_Time (
    TimeKey INT IDENTITY(1,1) PRIMARY KEY,
    [Hour] INT,
    FullTime TIME
);

-- 3. Tạo bảng Fact_Sales (Bảng Sự kiện)
CREATE TABLE Fact_Sales (
    SalesKey BIGINT IDENTITY(1,1) PRIMARY KEY,
    DateKey INT FOREIGN KEY REFERENCES Dim_Date(DateKey),
    TimeKey INT FOREIGN KEY REFERENCES Dim_Time(TimeKey),
    StoreKey INT FOREIGN KEY REFERENCES Dim_Store(StoreKey),
    ProductKey INT FOREIGN KEY REFERENCES Dim_Product(ProductKey),
    UserKey INT FOREIGN KEY REFERENCES Dim_User(UserKey),
    
    OrderDetail INT,
    [Status] INT,
    Price DECIMAL(18,2), -- Dùng Decimal chuẩn cho tiền tệ
    Quantity INT,
    Revenue DECIMAL(18,2)
);


-- Xóa FK
ALTER TABLE [dbo].[Fact_Sales] DROP CONSTRAINT FK__Fact_Sale__DateK__5441852A;

-- Drop và recreate Dim_Date
DROP TABLE [dbo].[Dim_Date];

CREATE TABLE [dbo].[Dim_Date] (
    DateKey  INT  IDENTITY(1,1) PRIMARY KEY,
    FullDate DATE NOT NULL,
    Day      INT  NOT NULL,
    Month    INT  NOT NULL,
    Year     INT  NOT NULL
);

-- Tạo lại FK
ALTER TABLE [dbo].[Fact_Sales]
ADD CONSTRAINT FK_Fact_Sales_Dim_Date
FOREIGN KEY (DateKey) REFERENCES [dbo].[Dim_Date](DateKey);


-------------------------
=======================================================
---- INDEX + VIEW ----
=======================================================

------------ NONCLUSTER INDEX -----------------
-- Fact_Sales
CREATE NONCLUSTERED INDEX IX_Fact_Sales_DateKey    ON Fact_Sales(DateKey);
CREATE NONCLUSTERED INDEX IX_Fact_Sales_TimeKey    ON Fact_Sales(TimeKey);
CREATE NONCLUSTERED INDEX IX_Fact_Sales_StoreKey   ON Fact_Sales(StoreKey);
CREATE NONCLUSTERED INDEX IX_Fact_Sales_ProductKey ON Fact_Sales(ProductKey);
CREATE NONCLUSTERED INDEX IX_Fact_Sales_UserKey    ON Fact_Sales(UserKey);

-- Dimension Tables
CREATE NONCLUSTERED INDEX IX_Dim_Date_FullDate      ON Dim_Date(FullDate);
CREATE NONCLUSTERED INDEX IX_Dim_Date_Month         ON Dim_Date(Month);
CREATE NONCLUSTERED INDEX IX_Dim_Date_Year          ON Dim_Date(Year);
CREATE NONCLUSTERED INDEX IX_Dim_Product_Detail     ON Dim_Product(Detail);
CREATE NONCLUSTERED INDEX IX_Dim_Product_Category   ON Dim_Product(Category);
CREATE NONCLUSTERED INDEX IX_Dim_Store_Location     ON Dim_Store(StoreLocation);
CREATE NONCLUSTERED INDEX IX_Dim_User_Email         ON Dim_User(EmailUser);
CREATE NONCLUSTERED INDEX IX_Dim_Time_Hour          ON Dim_Time(Hour);

-- Indexed Views (WITH SCHEMABINDING) --

DROP VIEW IF EXISTS vw_Revenue_By_Month_Store;
DROP VIEW IF EXISTS vw_Revenue_By_Category_Month;

-- View 1: tính doanh thu theo từng tháng + từng chi nhánh
CREATE VIEW vw_Revenue_By_Month_Store
WITH SCHEMABINDING AS
SELECT 
    d.Year,
    d.Month,
    s.StoreLocation,
    SUM(ISNULL(f.Revenue, 0))  AS TotalRevenue,
    SUM(ISNULL(f.Quantity, 0)) AS TotalQuantity,
    COUNT_BIG(*)               AS TotalTransactions
FROM dbo.Fact_Sales f
JOIN dbo.Dim_Date  d ON f.DateKey  = d.DateKey
JOIN dbo.Dim_Store s ON f.StoreKey = s.StoreKey
GROUP BY d.Year, d.Month, s.StoreLocation;

-- Tạo index cho view
CREATE UNIQUE CLUSTERED INDEX UCI_vw_Revenue_By_Month_Store
ON vw_Revenue_By_Month_Store(Year, Month, StoreLocation);
-- Xem data
SELECT * FROM vw_Revenue_By_Month_Store;

-- View 2:  tính doanh thu theo từng tháng + từng loại sản phẩm
CREATE VIEW vw_Revenue_By_Category_Month
WITH SCHEMABINDING AS
SELECT 
    d.Year,
    d.Month,
    p.Category,
    p.Type,
    SUM(ISNULL(f.Revenue, 0))  AS TotalRevenue,
    SUM(ISNULL(f.Quantity, 0)) AS TotalQuantity,
    COUNT_BIG(*)               AS TotalTransactions
FROM dbo.Fact_Sales f
JOIN dbo.Dim_Date    d ON f.DateKey    = d.DateKey
JOIN dbo.Dim_Product p ON f.ProductKey = p.ProductKey
GROUP BY d.Year, d.Month, p.Category, p.Type;

-- Tạo index cho view
CREATE UNIQUE CLUSTERED INDEX UCI_vw_Revenue_By_Category_Month
ON vw_Revenue_By_Category_Month(Year, Month, Category, Type);

-- Xem data
SELECT * FROM vw_Revenue_By_Category_Month;


================================
-- PARTITION
================================
-- Partition Function: 4 boundaries → 5 partitions
CREATE PARTITION FUNCTION PF_ByYear (INT)
AS RANGE LEFT FOR VALUES (2021, 2022, 2023, 2024);
-- Partition 1: Year <= 2021
-- Partition 2: Year = 2022
-- Partition 3: Year = 2023
-- Partition 4: Year = 2024
-- Partition 5: Year >= 2025 (DEFAULT - tương lai)

-- Partition Scheme
-- Tạo Partition Function (DateKey dạng INT: 20200101, 20210101,...)
CREATE PARTITION FUNCTION PF_ByYear (INT)
AS RANGE RIGHT FOR VALUES (20210101, 20220101, 20230101, 20240101, 20250101);

-- Tạo Partition Scheme trỏ vào filegroup PRIMARY
CREATE PARTITION SCHEME PS_ByYear
AS PARTITION PF_ByYear
ALL TO ([PRIMARY]);

-- Tạo NONCLUSTERED Index dùng PS_ByYear
CREATE NONCLUSTERED INDEX IX_Fact_Sales_DateKey_Part
ON Fact_Sales(DateKey)
ON PS_ByYear(DateKey);

-- Xem data của partition
SELECT TOP 10 *
FROM Fact_Sales
WHERE $PARTITION.PF_ByYear(DateKey) = 3

-- = 1 → partition đầu tiên (DateKey < 20210101)
-- = 2 → partition năm 2021 (20210101 <= DateKey < 20220101)
-- = 3 → partition năm 2022 (20220101 <= DateKey < 20230101)
-- = 4 → partition năm 2023 (20230101 <= DateKey < 20240101)
-- = 5 → partition năm 2024 (20240101 <= DateKey < 20250101)
-- = 6 → partition năm 2025 (DateKey >= 20250101)



