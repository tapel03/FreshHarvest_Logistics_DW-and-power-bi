
USE master;
GO

IF DB_ID('FreshHarvest_DW') IS NOT NULL
BEGIN
    ALTER DATABASE FreshHarvest_DW SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE FreshHarvest_DW;
END;
GO

CREATE DATABASE FreshHarvest_DW;
GO

USE FreshHarvest_DW;
GO

CREATE TABLE dbo.DimDate (
    DateKey INT NOT NULL PRIMARY KEY,
    FullDate DATE NOT NULL UNIQUE,
    DayNo TINYINT NOT NULL,
    DayName VARCHAR(20) NOT NULL,
    MonthNo TINYINT NOT NULL,
    MonthName VARCHAR(20) NOT NULL,
    QuarterNo TINYINT NOT NULL,
    YearNo SMALLINT NOT NULL
);
GO

CREATE TABLE dbo.DimProduct (
    ProductKey INT IDENTITY(1,1) PRIMARY KEY,
    SourceProductID INT NOT NULL UNIQUE,
    ProductName VARCHAR(150) NOT NULL,
    CategoryName VARCHAR(100) NOT NULL,
    StorageRequirement VARCHAR(100) NOT NULL,
    ShelfLifeDays INT NOT NULL,
    PerishabilityBand VARCHAR(30) NOT NULL,
    Unit VARCHAR(20) NOT NULL
);
GO

CREATE TABLE dbo.DimCustomer (
    CustomerKey INT IDENTITY(1,1) PRIMARY KEY,
    SourceCustomerID INT NOT NULL UNIQUE,
    CustomerName VARCHAR(150) NOT NULL,
    CustomerType VARCHAR(50) NOT NULL,
    RegistrationDate DATE NOT NULL,
    RegistrationYear SMALLINT NOT NULL
);
GO

CREATE TABLE dbo.DimRoute (
    RouteKey INT IDENTITY(1,1) PRIMARY KEY,
    SourceRouteID INT NULL UNIQUE,
    StartLocation VARCHAR(150) NOT NULL,
    EndLocation VARCHAR(150) NOT NULL,
    DistanceKm DECIMAL(8,2) NOT NULL,
    DistanceBand VARCHAR(40) NOT NULL,
    EstimatedDurationMinutes INT NOT NULL
);
GO

CREATE TABLE dbo.DimStatus (
    StatusKey INT IDENTITY(1,1) PRIMARY KEY,
    OrderStatus VARCHAR(30) NOT NULL,
    DeliveryStatus VARCHAR(30) NOT NULL,
    PaymentStatus VARCHAR(30) NOT NULL,
    FulfilmentStage VARCHAR(40) NOT NULL,
    CONSTRAINT UQ_DimStatus UNIQUE
    (OrderStatus, DeliveryStatus, PaymentStatus, FulfilmentStage)
);
GO

CREATE TABLE dbo.FactSales (
    SalesKey BIGINT IDENTITY(1,1) PRIMARY KEY,
    DateKey INT NOT NULL,
    ProductKey INT NOT NULL,
    CustomerKey INT NOT NULL,
    RouteKey INT NOT NULL,
    StatusKey INT NOT NULL,
    OrderID INT NOT NULL,
    InvoiceID INT NULL,
    QuantitySold DECIMAL(10,2) NOT NULL,
    UnitSellingPrice DECIMAL(10,2) NOT NULL,
    SalesAmount DECIMAL(14,2) NOT NULL,
    CONSTRAINT FK_FactSales_Date FOREIGN KEY (DateKey) REFERENCES dbo.DimDate(DateKey),
    CONSTRAINT FK_FactSales_Product FOREIGN KEY (ProductKey) REFERENCES dbo.DimProduct(ProductKey),
    CONSTRAINT FK_FactSales_Customer FOREIGN KEY (CustomerKey) REFERENCES dbo.DimCustomer(CustomerKey),
    CONSTRAINT FK_FactSales_Route FOREIGN KEY (RouteKey) REFERENCES dbo.DimRoute(RouteKey),
    CONSTRAINT FK_FactSales_Status FOREIGN KEY (StatusKey) REFERENCES dbo.DimStatus(StatusKey)
);
GO

/* ========================= ETL ========================= */

INSERT INTO dbo.DimDate
(DateKey, FullDate, DayNo, DayName, MonthNo, MonthName, QuarterNo, YearNo)
SELECT DISTINCT
    CONVERT(INT, CONVERT(CHAR(8), CAST(o.OrderDate AS DATE), 112)),
    CAST(o.OrderDate AS DATE),
    DAY(o.OrderDate),
    DATENAME(WEEKDAY, o.OrderDate),
    MONTH(o.OrderDate),
    DATENAME(MONTH, o.OrderDate),
    DATEPART(QUARTER, o.OrderDate),
    YEAR(o.OrderDate)
FROM Fresh_Harvest.dbo.[Order] AS o;
GO

INSERT INTO dbo.DimProduct
(SourceProductID, ProductName, CategoryName, StorageRequirement, ShelfLifeDays, PerishabilityBand, Unit)
SELECT
    p.ProductID,
    LTRIM(RTRIM(p.ProductName)),
    LTRIM(RTRIM(pc.CategoryName)),
    LTRIM(RTRIM(pc.StorageRequirement)),
    p.ShelfLifeDays,
    CASE
        WHEN p.ShelfLifeDays <= 5 THEN 'Highly Perishable'
        WHEN p.ShelfLifeDays <= 14 THEN 'Perishable'
        ELSE 'Extended Shelf Life'
    END,
    LTRIM(RTRIM(p.Unit))
FROM Fresh_Harvest.dbo.Product AS p
INNER JOIN Fresh_Harvest.dbo.ProductCategory AS pc
    ON pc.CategoryID = p.CategoryID;
GO

INSERT INTO dbo.DimCustomer
(SourceCustomerID, CustomerName, CustomerType, RegistrationDate, RegistrationYear)
SELECT
    c.CustomerID,
    LTRIM(RTRIM(c.CustomerName)),
    LTRIM(RTRIM(c.CustomerType)),
    CAST(c.RegistrationDate AS DATE),
    YEAR(c.RegistrationDate)
FROM Fresh_Harvest.dbo.Customer AS c;
GO

INSERT INTO dbo.DimRoute
(SourceRouteID, StartLocation, EndLocation, DistanceKm, DistanceBand, EstimatedDurationMinutes)
VALUES
(NULL, 'Unknown', 'Unknown', 0.00, 'Unknown', 0);
GO

INSERT INTO dbo.DimRoute
(SourceRouteID, StartLocation, EndLocation, DistanceKm, DistanceBand, EstimatedDurationMinutes)
SELECT
    r.RouteID,
    LTRIM(RTRIM(r.StartLocation)),
    LTRIM(RTRIM(r.EndLocation)),
    r.Distance,
    CASE
        WHEN r.Distance <= 50 THEN 'Local (0-50 km)'
        WHEN r.Distance <= 500 THEN 'Regional (51-500 km)'
        ELSE 'Long Distance (>500 km)'
    END,
    r.EstimatedDurationMinutes
FROM Fresh_Harvest.dbo.Route AS r;
GO

INSERT INTO dbo.DimStatus
(OrderStatus, DeliveryStatus, PaymentStatus, FulfilmentStage)
SELECT DISTINCT
    COALESCE(o.Status, 'Unknown'),
    COALESCE(d.Status, 'Unknown'),
    COALESCE(i.PaymentStatus, 'Unknown'),
    CASE
        WHEN o.Status = 'Cancelled' OR d.Status = 'Cancelled' THEN 'Cancelled'
        WHEN d.Status = 'Delivered' AND i.PaymentStatus = 'Paid' THEN 'Completed'
        WHEN d.Status = 'Delivered' THEN 'Delivered - Payment Open'
        WHEN d.Status = 'In Transit' THEN 'In Transit'
        WHEN d.Status = 'Scheduled' THEN 'Scheduled'
        WHEN o.Status = 'Processing' THEN 'Processing'
        WHEN o.Status = 'Pending' THEN 'Pending'
        ELSE COALESCE(o.Status, 'Unknown')
    END
FROM Fresh_Harvest.dbo.[Order] AS o
LEFT JOIN Fresh_Harvest.dbo.Delivery AS d ON d.OrderID = o.OrderID
LEFT JOIN Fresh_Harvest.dbo.Invoice AS i ON i.OrderID = o.OrderID;
GO

INSERT INTO dbo.FactSales
(DateKey, ProductKey, CustomerKey, RouteKey, StatusKey, OrderID, InvoiceID,
 QuantitySold, UnitSellingPrice, SalesAmount)
SELECT
    dd.DateKey,
    dp.ProductKey,
    dc.CustomerKey,
    COALESCE(dr.RouteKey, ur.RouteKey),
    ds.StatusKey,
    o.OrderID,
    i.InvoiceID,
    oi.Quantity,
    oi.UnitPrice,
    CAST(oi.Quantity * oi.UnitPrice AS DECIMAL(14,2))
FROM Fresh_Harvest.dbo.[Order] AS o
INNER JOIN Fresh_Harvest.dbo.OrderItem AS oi ON oi.OrderID = o.OrderID
INNER JOIN dbo.DimDate AS dd ON dd.FullDate = CAST(o.OrderDate AS DATE)
INNER JOIN dbo.DimProduct AS dp ON dp.SourceProductID = oi.ProductID
INNER JOIN dbo.DimCustomer AS dc ON dc.SourceCustomerID = o.CustomerID
LEFT JOIN Fresh_Harvest.dbo.Delivery AS d ON d.OrderID = o.OrderID
LEFT JOIN Fresh_Harvest.dbo.Route AS r ON r.RouteID = d.RouteID
LEFT JOIN dbo.DimRoute AS dr ON dr.SourceRouteID = r.RouteID
CROSS APPLY (
    SELECT TOP 1 RouteKey
    FROM dbo.DimRoute
    WHERE SourceRouteID IS NULL
) AS ur
LEFT JOIN Fresh_Harvest.dbo.Invoice AS i ON i.OrderID = o.OrderID
INNER JOIN dbo.DimStatus AS ds
    ON ds.OrderStatus = COALESCE(o.Status, 'Unknown')
   AND ds.DeliveryStatus = COALESCE(d.Status, 'Unknown')
   AND ds.PaymentStatus = COALESCE(i.PaymentStatus, 'Unknown');
GO

/* ========================= VIEW TABLES ========================= */

SELECT * FROM dbo.DimDate;
SELECT * FROM dbo.DimProduct;
SELECT * FROM dbo.DimCustomer;
SELECT * FROM dbo.DimRoute;
SELECT * FROM dbo.DimStatus;
SELECT * FROM dbo.FactSales;
GO

/* ========================= VALIDATION ========================= */

SELECT 'DimDate' AS TableName, COUNT(*) AS TotalRows FROM dbo.DimDate
UNION ALL SELECT 'DimProduct', COUNT(*) FROM dbo.DimProduct
UNION ALL SELECT 'DimCustomer', COUNT(*) FROM dbo.DimCustomer
UNION ALL SELECT 'DimRoute', COUNT(*) FROM dbo.DimRoute
UNION ALL SELECT 'DimStatus', COUNT(*) FROM dbo.DimStatus
UNION ALL SELECT 'FactSales', COUNT(*) FROM dbo.FactSales;
GO

SELECT
    COUNT(*) AS FactRows,
    CAST(SUM(SalesAmount) AS DECIMAL(14,2)) AS TotalSalesRevenue,
    COUNT(DISTINCT OrderID) AS DistinctOrders
FROM dbo.FactSales;
GO

SELECT
    fs.SalesKey,
    dd.FullDate AS SaleDate,
    dc.CustomerName,
    dc.CustomerType,
    dp.ProductName,
    dp.CategoryName,
    dr.EndLocation AS Destination,
    dr.DistanceBand,
    ds.OrderStatus,
    ds.DeliveryStatus,
    ds.PaymentStatus,
    ds.FulfilmentStage,
    fs.QuantitySold,
    fs.UnitSellingPrice,
    fs.SalesAmount
FROM dbo.FactSales AS fs
INNER JOIN dbo.DimDate AS dd ON dd.DateKey = fs.DateKey
INNER JOIN dbo.DimCustomer AS dc ON dc.CustomerKey = fs.CustomerKey
INNER JOIN dbo.DimProduct AS dp ON dp.ProductKey = fs.ProductKey
INNER JOIN dbo.DimRoute AS dr ON dr.RouteKey = fs.RouteKey
INNER JOIN dbo.DimStatus AS ds ON ds.StatusKey = fs.StatusKey
ORDER BY fs.SalesKey;
GO

SELECT
    SUM(CASE WHEN dd.DateKey IS NULL THEN 1 ELSE 0 END) AS MissingDateKeys,
    SUM(CASE WHEN dp.ProductKey IS NULL THEN 1 ELSE 0 END) AS MissingProductKeys,
    SUM(CASE WHEN dc.CustomerKey IS NULL THEN 1 ELSE 0 END) AS MissingCustomerKeys,
    SUM(CASE WHEN dr.RouteKey IS NULL THEN 1 ELSE 0 END) AS MissingRouteKeys,
    SUM(CASE WHEN ds.StatusKey IS NULL THEN 1 ELSE 0 END) AS MissingStatusKeys
FROM dbo.FactSales AS fs
LEFT JOIN dbo.DimDate AS dd ON dd.DateKey = fs.DateKey
LEFT JOIN dbo.DimProduct AS dp ON dp.ProductKey = fs.ProductKey
LEFT JOIN dbo.DimCustomer AS dc ON dc.CustomerKey = fs.CustomerKey
LEFT JOIN dbo.DimRoute AS dr ON dr.RouteKey = fs.RouteKey
LEFT JOIN dbo.DimStatus AS ds ON ds.StatusKey = fs.StatusKey;
GO

/* ========================= C1 SLICE ========================= */

SELECT
    dp.CategoryName,
    CAST(SUM(fs.SalesAmount) AS DECIMAL(14,2)) AS SalesRevenue
FROM dbo.FactSales AS fs
INNER JOIN dbo.DimDate AS dd ON dd.DateKey = fs.DateKey
INNER JOIN dbo.DimProduct AS dp ON dp.ProductKey = fs.ProductKey
WHERE dd.YearNo = 2026
  AND dd.MonthNo = 5
GROUP BY dp.CategoryName
ORDER BY SalesRevenue DESC;
GO

/* ========================= C2 DICE ========================= */

SELECT
    dc.CustomerType,
    dp.CategoryName,
    CAST(SUM(fs.SalesAmount) AS DECIMAL(14,2)) AS SalesRevenue
FROM dbo.FactSales AS fs
INNER JOIN dbo.DimDate AS dd ON dd.DateKey = fs.DateKey
INNER JOIN dbo.DimCustomer AS dc ON dc.CustomerKey = fs.CustomerKey
INNER JOIN dbo.DimProduct AS dp ON dp.ProductKey = fs.ProductKey
WHERE dd.YearNo = 2026
  AND dc.CustomerType IN ('Retailer', 'Exporter')
  AND dp.CategoryName IN ('Citrus Fruits', 'Leafy Greens')
GROUP BY dc.CustomerType, dp.CategoryName
ORDER BY dc.CustomerType, SalesRevenue DESC;
GO

/* ========================= C3 DRILL-DOWN ========================= */

SELECT
    dd.YearNo,
    dd.MonthName,
    dd.FullDate,
    CAST(SUM(fs.SalesAmount) AS DECIMAL(14,2)) AS DailySalesRevenue
FROM dbo.FactSales AS fs
INNER JOIN dbo.DimDate AS dd ON dd.DateKey = fs.DateKey
WHERE dd.YearNo = 2026
  AND dd.MonthNo = 5
GROUP BY dd.YearNo, dd.MonthName, dd.FullDate
ORDER BY dd.FullDate;
GO

/* ========================= C4 ROLL-UP ========================= */

SELECT
    CASE
        WHEN GROUPING(dp.CategoryName) = 1 THEN 'ALL CATEGORIES'
        ELSE dp.CategoryName
    END AS CategoryName,
    CASE
        WHEN GROUPING(dp.CategoryName) = 1 THEN 'GRAND TOTAL'
        WHEN GROUPING(dp.ProductName) = 1 THEN 'CATEGORY TOTAL'
        ELSE dp.ProductName
    END AS ProductLevel,
    CAST(SUM(fs.SalesAmount) AS DECIMAL(14,2)) AS SalesRevenue
FROM dbo.FactSales AS fs
INNER JOIN dbo.DimProduct AS dp ON dp.ProductKey = fs.ProductKey
GROUP BY ROLLUP(dp.CategoryName, dp.ProductName);
GO

/* ========================= C5 PIVOT ========================= */

SELECT
    CategoryName,
    ISNULL([Retailer], 0) AS Retailer,
    ISNULL([Wholesaler], 0) AS Wholesaler,
    ISNULL([Exporter], 0) AS Exporter
FROM (
    SELECT
        dp.CategoryName,
        dc.CustomerType,
        fs.SalesAmount
    FROM dbo.FactSales AS fs
    INNER JOIN dbo.DimProduct AS dp ON dp.ProductKey = fs.ProductKey
    INNER JOIN dbo.DimCustomer AS dc ON dc.CustomerKey = fs.CustomerKey
) AS SourceData
PIVOT (
    SUM(SalesAmount)
    FOR CustomerType IN ([Retailer], [Wholesaler], [Exporter])
) AS PivotTable
ORDER BY CategoryName;
GO


/* ---------- OVERALL KPIs ---------- */
SELECT
    CAST(SUM(SalesAmount) AS DECIMAL(14,2)) AS TotalSalesRevenue,
    CAST(SUM(QuantitySold) AS DECIMAL(14,2)) AS TotalQuantitySold,
    COUNT(DISTINCT OrderID) AS TotalOrders,
    CAST(SUM(SalesAmount) / NULLIF(COUNT(DISTINCT OrderID),0) AS DECIMAL(14,2)) AS AverageOrderValue
FROM dbo.FactSales;
GO

/* ---------- Q1: SALES REVENUE BY YEAR ---------- */
SELECT
    dd.YearNo,
    CAST(SUM(fs.SalesAmount) AS DECIMAL(14,2)) AS SalesRevenue
FROM dbo.FactSales fs
JOIN dbo.DimDate dd ON dd.DateKey = fs.DateKey
GROUP BY dd.YearNo
ORDER BY dd.YearNo;
GO

/* ---------- Q1: SALES REVENUE BY QUARTER ---------- */
SELECT
    dd.YearNo,
    dd.QuarterNo,
    CAST(SUM(fs.SalesAmount) AS DECIMAL(14,2)) AS SalesRevenue
FROM dbo.FactSales fs
JOIN dbo.DimDate dd ON dd.DateKey = fs.DateKey
GROUP BY dd.YearNo, dd.QuarterNo
ORDER BY dd.YearNo, dd.QuarterNo;
GO

/* ---------- Q1: SALES REVENUE BY MONTH ---------- */
SELECT
    dd.YearNo,
    dd.MonthNo,
    dd.MonthName,
    CAST(SUM(fs.SalesAmount) AS DECIMAL(14,2)) AS SalesRevenue
FROM dbo.FactSales fs
JOIN dbo.DimDate dd ON dd.DateKey = fs.DateKey
GROUP BY dd.YearNo, dd.MonthNo, dd.MonthName
ORDER BY dd.YearNo, dd.MonthNo;
GO

/* ---------- Q1: QUANTITY SOLD BY YEAR ---------- */
SELECT
    dd.YearNo,
    CAST(SUM(fs.QuantitySold) AS DECIMAL(14,2)) AS QuantitySold
FROM dbo.FactSales fs
JOIN dbo.DimDate dd ON dd.DateKey = fs.DateKey
GROUP BY dd.YearNo
ORDER BY dd.YearNo;
GO

/* ---------- Q1: QUANTITY SOLD BY QUARTER ---------- */
SELECT
    dd.YearNo,
    dd.QuarterNo,
    CAST(SUM(fs.QuantitySold) AS DECIMAL(14,2)) AS QuantitySold
FROM dbo.FactSales fs
JOIN dbo.DimDate dd ON dd.DateKey = fs.DateKey
GROUP BY dd.YearNo, dd.QuarterNo
ORDER BY dd.YearNo, dd.QuarterNo;
GO

/* ---------- Q1: QUANTITY SOLD BY MONTH ---------- */
SELECT
    dd.YearNo,
    dd.MonthNo,
    dd.MonthName,
    CAST(SUM(fs.QuantitySold) AS DECIMAL(14,2)) AS QuantitySold
FROM dbo.FactSales fs
JOIN dbo.DimDate dd ON dd.DateKey = fs.DateKey
GROUP BY dd.YearNo, dd.MonthNo, dd.MonthName
ORDER BY dd.YearNo, dd.MonthNo;
GO

/* ---------- Q2: PRODUCT CATEGORY SALES VALUE ---------- */
SELECT
    dp.CategoryName,
    CAST(SUM(fs.SalesAmount) AS DECIMAL(14,2)) AS SalesRevenue
FROM dbo.FactSales fs
JOIN dbo.DimProduct dp ON dp.ProductKey = fs.ProductKey
GROUP BY dp.CategoryName
ORDER BY SalesRevenue DESC;
GO

/* ---------- Q2: PRODUCT CATEGORY SALES VOLUME ---------- */
SELECT
    dp.CategoryName,
    CAST(SUM(fs.QuantitySold) AS DECIMAL(14,2)) AS QuantitySold
FROM dbo.FactSales fs
JOIN dbo.DimProduct dp ON dp.ProductKey = fs.ProductKey
GROUP BY dp.CategoryName
ORDER BY QuantitySold DESC;
GO

/* ---------- Q3: REVENUE BY CUSTOMER TYPE ---------- */
SELECT
    dc.CustomerType,
    CAST(SUM(fs.SalesAmount) AS DECIMAL(14,2)) AS SalesRevenue
FROM dbo.FactSales fs
JOIN dbo.DimCustomer dc ON dc.CustomerKey = fs.CustomerKey
GROUP BY dc.CustomerType
ORDER BY SalesRevenue DESC;
GO

/* ---------- Q3: REVENUE BY INDIVIDUAL CUSTOMER ---------- */
SELECT
    dc.CustomerName,
    dc.CustomerType,
    CAST(SUM(fs.SalesAmount) AS DECIMAL(14,2)) AS SalesRevenue
FROM dbo.FactSales fs
JOIN dbo.DimCustomer dc ON dc.CustomerKey = fs.CustomerKey
GROUP BY dc.CustomerName, dc.CustomerType
ORDER BY SalesRevenue DESC;
GO

/* ---------- Q4: REVENUE BY DELIVERY DESTINATION ---------- */
SELECT
    dr.EndLocation AS DeliveryDestination,
    CAST(SUM(fs.SalesAmount) AS DECIMAL(14,2)) AS SalesRevenue
FROM dbo.FactSales fs
JOIN dbo.DimRoute dr ON dr.RouteKey = fs.RouteKey
GROUP BY dr.EndLocation
ORDER BY SalesRevenue DESC;
GO

/* ---------- Q4: REVENUE BY DISTANCE BAND ---------- */
SELECT
    dr.DistanceBand,
    CAST(SUM(fs.SalesAmount) AS DECIMAL(14,2)) AS SalesRevenue
FROM dbo.FactSales fs
JOIN dbo.DimRoute dr ON dr.RouteKey = fs.RouteKey
GROUP BY dr.DistanceBand
ORDER BY SalesRevenue DESC;
GO

/* ---------- Q5: REVENUE BY PAYMENT STATUS ---------- */
SELECT
    ds.PaymentStatus,
    CAST(SUM(fs.SalesAmount) AS DECIMAL(14,2)) AS SalesRevenue
FROM dbo.FactSales fs
JOIN dbo.DimStatus ds ON ds.StatusKey = fs.StatusKey
GROUP BY ds.PaymentStatus
ORDER BY SalesRevenue DESC;
GO

/* ---------- Q5: REVENUE BY ORDER STATUS ---------- */
SELECT
    ds.OrderStatus,
    CAST(SUM(fs.SalesAmount) AS DECIMAL(14,2)) AS SalesRevenue
FROM dbo.FactSales fs
JOIN dbo.DimStatus ds ON ds.StatusKey = fs.StatusKey
GROUP BY ds.OrderStatus
ORDER BY SalesRevenue DESC;
GO

/* ---------- DETAILED STAR-SCHEMA RESULT FOR CHECKING ---------- */
SELECT
    fs.SalesKey,
    dd.FullDate,
    dd.MonthName,
    dd.QuarterNo,
    dd.YearNo,
    dp.ProductName,
    dp.CategoryName,
    dc.CustomerName,
    dc.CustomerType,
    dr.StartLocation,
    dr.EndLocation,
    dr.DistanceBand,
    ds.OrderStatus,
    ds.DeliveryStatus,
    ds.PaymentStatus,
    ds.FulfilmentStage,
    fs.OrderID,
    fs.InvoiceID,
    fs.QuantitySold,
    fs.UnitSellingPrice,
    fs.SalesAmount
FROM dbo.FactSales fs
JOIN dbo.DimDate dd ON dd.DateKey = fs.DateKey
JOIN dbo.DimProduct dp ON dp.ProductKey = fs.ProductKey
JOIN dbo.DimCustomer dc ON dc.CustomerKey = fs.CustomerKey
JOIN dbo.DimRoute dr ON dr.RouteKey = fs.RouteKey
JOIN dbo.DimStatus ds ON ds.StatusKey = fs.StatusKey
ORDER BY dd.FullDate, fs.SalesKey;
GO

