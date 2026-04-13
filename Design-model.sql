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
