
USE master;
GO

IF DB_ID('Fresh_Harvest') IS NOT NULL
BEGIN
    ALTER DATABASE Fresh_Harvest SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Fresh_Harvest;
END;
GO

CREATE DATABASE Fresh_Harvest;
GO

USE Fresh_Harvest;
GO



CREATE TABLE Supplier (
    SupplierID INT IDENTITY(1,1) PRIMARY KEY,
    SupplierName VARCHAR(150) NOT NULL,
    ContactNumber VARCHAR(20) NOT NULL,
    Email VARCHAR(100) NOT NULL UNIQUE,
    Address VARCHAR(255) NOT NULL,
    RegistrationNo VARCHAR(50) NOT NULL UNIQUE,
    ActiveStatus BIT NOT NULL DEFAULT 1
);
GO

CREATE TABLE Farmer (
    FarmerID INT IDENTITY(1,1) PRIMARY KEY,
    FarmerName VARCHAR(150) NOT NULL,
    FarmLocation VARCHAR(255) NOT NULL,
    ContactNumber VARCHAR(20) NOT NULL,
    Email VARCHAR(100) NOT NULL UNIQUE,
    FarmSizeHectares DECIMAL(10,2) NOT NULL CHECK (FarmSizeHectares > 0)
);
GO

CREATE TABLE SupplierFarmer (
    SupplierID INT NOT NULL,
    FarmerID INT NOT NULL,
    ContractStartDate DATE NOT NULL,
    ContractEndDate DATE NULL,
    CONSTRAINT PK_SupplierFarmer PRIMARY KEY (SupplierID, FarmerID),
    CONSTRAINT FK_SupplierFarmer_Supplier FOREIGN KEY (SupplierID) REFERENCES Supplier(SupplierID),
    CONSTRAINT FK_SupplierFarmer_Farmer FOREIGN KEY (FarmerID) REFERENCES Farmer(FarmerID)
);
GO

CREATE TABLE ProductCategory (
    CategoryID INT IDENTITY(1,1) PRIMARY KEY,
    CategoryName VARCHAR(100) NOT NULL UNIQUE,
    StorageRequirement VARCHAR(100) NOT NULL,
    HandlingInstructions VARCHAR(255) NULL
);
GO

CREATE TABLE Product (
    ProductID INT IDENTITY(1,1) PRIMARY KEY,
    CategoryID INT NOT NULL,
    ProductName VARCHAR(150) NOT NULL,
    UnitPrice DECIMAL(10,2) NOT NULL CHECK (UnitPrice >= 0),
    ShelfLifeDays INT NOT NULL CHECK (ShelfLifeDays > 0),
    Unit VARCHAR(20) NOT NULL,
    CONSTRAINT FK_Product_Category FOREIGN KEY (CategoryID) REFERENCES ProductCategory(CategoryID)
);
GO

CREATE TABLE Batch (
    BatchID INT IDENTITY(1,1) PRIMARY KEY,
    FarmerID INT NOT NULL,
    SupplierID INT NOT NULL,
    ArrivalDate DATETIME NOT NULL DEFAULT GETDATE(),
    TotalQuantity DECIMAL(10,2) NOT NULL CHECK (TotalQuantity > 0),
    QualityStatus VARCHAR(50) NOT NULL CHECK (QualityStatus IN ('Accepted','Rejected','Pending Inspection')),
    ExpiryDate DATE NOT NULL,
    CONSTRAINT FK_Batch_Farmer FOREIGN KEY (FarmerID) REFERENCES Farmer(FarmerID),
    CONSTRAINT FK_Batch_Supplier FOREIGN KEY (SupplierID) REFERENCES Supplier(SupplierID)
);
GO

CREATE TABLE BatchProduct (
    BatchID INT NOT NULL,
    ProductID INT NOT NULL,
    Quantity DECIMAL(10,2) NOT NULL CHECK (Quantity > 0),
    UnitCost DECIMAL(10,2) NOT NULL CHECK (UnitCost >= 0),
    CONSTRAINT PK_BatchProduct PRIMARY KEY (BatchID, ProductID),
    CONSTRAINT FK_BatchProduct_Batch FOREIGN KEY (BatchID) REFERENCES Batch(BatchID),
    CONSTRAINT FK_BatchProduct_Product FOREIGN KEY (ProductID) REFERENCES Product(ProductID)
);
GO

CREATE TABLE Warehouse (
    WarehouseID INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeID INT NULL,
    Location VARCHAR(255) NOT NULL,
    TotalCapacity DECIMAL(10,2) NOT NULL CHECK (TotalCapacity > 0),
    ContactNumber VARCHAR(20) NOT NULL
);
GO

CREATE TABLE SectionType (
    SectionTypeID INT IDENTITY(1,1) PRIMARY KEY,
    SectionType VARCHAR(50) NOT NULL UNIQUE,
    DefaultTempZone VARCHAR(50) NOT NULL,
    HandlingNotes VARCHAR(255) NULL
);
GO

CREATE TABLE StorageSection (
    SectionID INT IDENTITY(1,1) PRIMARY KEY,
    WarehouseID INT NOT NULL,
    SectionTypeID INT NOT NULL,
    Capacity DECIMAL(10,2) NOT NULL CHECK (Capacity > 0),
    CurrentOccupancy DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (CurrentOccupancy >= 0),
    CONSTRAINT FK_StorageSection_Warehouse FOREIGN KEY (WarehouseID) REFERENCES Warehouse(WarehouseID),
    CONSTRAINT FK_StorageSection_SectionType FOREIGN KEY (SectionTypeID) REFERENCES SectionType(SectionTypeID)
);
GO

CREATE TABLE Inventory (
    InventoryID INT IDENTITY(1,1) PRIMARY KEY,
    SectionID INT NOT NULL,
    ProductID INT NOT NULL,
    QuantityAvailable DECIMAL(10,2) NOT NULL CHECK (QuantityAvailable >= 0),
    LastUpdated DATETIME NOT NULL DEFAULT GETDATE(),
    MinStockLevel DECIMAL(10,2) NOT NULL CHECK (MinStockLevel >= 0),
    MaxStockLevel DECIMAL(10,2) NOT NULL CHECK (MaxStockLevel >= 0),
    CONSTRAINT FK_Inventory_Section FOREIGN KEY (SectionID) REFERENCES StorageSection(SectionID),
    CONSTRAINT FK_Inventory_Product FOREIGN KEY (ProductID) REFERENCES Product(ProductID)
);
GO

CREATE TABLE Employee (
    EmployeeID INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeName VARCHAR(150) NOT NULL,
    Role VARCHAR(100) NOT NULL,
    Department VARCHAR(100) NOT NULL,
    ContactNumber VARCHAR(20) NOT NULL,
    Email VARCHAR(100) NOT NULL UNIQUE,
    HireDate DATE NOT NULL,
    Salary DECIMAL(12,2) NOT NULL CHECK (Salary >= 0)
);
GO

ALTER TABLE Warehouse
ADD CONSTRAINT FK_Warehouse_Employee
FOREIGN KEY (EmployeeID) REFERENCES Employee(EmployeeID);
GO

CREATE TABLE Equipment (
    EquipmentID INT IDENTITY(1,1) PRIMARY KEY,
    WarehouseID INT NOT NULL,
    EquipmentName VARCHAR(150) NOT NULL,
    EquipmentType VARCHAR(100) NOT NULL,
    PurchaseDate DATE NOT NULL,
    LastMaintenanceDate DATE NULL,
    CONSTRAINT FK_Equipment_Warehouse FOREIGN KEY (WarehouseID) REFERENCES Warehouse(WarehouseID)
);
GO

CREATE TABLE Customer (
    CustomerID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerName VARCHAR(150) NOT NULL,
    ContactNumber VARCHAR(20) NOT NULL,
    Address VARCHAR(255) NOT NULL,
    Email VARCHAR(100) NOT NULL UNIQUE,
    CustomerType VARCHAR(50) NOT NULL CHECK (CustomerType IN ('Retailer','Exporter','Wholesaler')),
    RegistrationDate DATE NOT NULL DEFAULT GETDATE()
);
GO

CREATE TABLE [Order] (
    OrderID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT NOT NULL,
    OrderDate DATETIME NOT NULL DEFAULT GETDATE(),
    Status VARCHAR(30) NOT NULL CHECK (Status IN ('Pending','Processing','Dispatched','Delivered','Cancelled')),
    DeliveryAddress VARCHAR(255) NOT NULL,
    Notes VARCHAR(500) NULL,
    CONSTRAINT FK_Order_Customer FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID)
);
GO

CREATE TABLE OrderItem (
    OrderID INT NOT NULL,
    ProductID INT NOT NULL,
    Quantity DECIMAL(10,2) NOT NULL CHECK (Quantity > 0),
    UnitPrice DECIMAL(10,2) NOT NULL CHECK (UnitPrice >= 0),
    CONSTRAINT PK_OrderItem PRIMARY KEY (OrderID, ProductID),
    CONSTRAINT FK_OrderItem_Order FOREIGN KEY (OrderID) REFERENCES [Order](OrderID),
    CONSTRAINT FK_OrderItem_Product FOREIGN KEY (ProductID) REFERENCES Product(ProductID)
);
GO

CREATE TABLE TaxRate (
    TaxRateID INT IDENTITY(1,1) PRIMARY KEY,
    RatePercent DECIMAL(5,2) NOT NULL CHECK (RatePercent >= 0),
    EffectiveDate DATE NOT NULL,
    Description VARCHAR(100) NULL
);
GO

CREATE TABLE Invoice (
    InvoiceID INT IDENTITY(1,1) PRIMARY KEY,
    OrderID INT NOT NULL UNIQUE,
    TaxRateID INT NOT NULL,
    TotalAmount DECIMAL(12,2) NOT NULL CHECK (TotalAmount >= 0),
    IssueDate DATE NOT NULL DEFAULT GETDATE(),
    DueDate DATE NOT NULL,
    PaymentStatus VARCHAR(30) NOT NULL CHECK (PaymentStatus IN ('Unpaid','Partially Paid','Paid','Overdue')),
    CONSTRAINT FK_Invoice_Order FOREIGN KEY (OrderID) REFERENCES [Order](OrderID),
    CONSTRAINT FK_Invoice_TaxRate FOREIGN KEY (TaxRateID) REFERENCES TaxRate(TaxRateID)
);
GO

CREATE TABLE Payment (
    PaymentID INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeID INT NOT NULL,
    InvoiceID INT NOT NULL,
    PaymentDate DATETIME NOT NULL DEFAULT GETDATE(),
    Amount DECIMAL(12,2) NOT NULL CHECK (Amount > 0),
    PaymentMethod VARCHAR(50) NOT NULL CHECK (PaymentMethod IN ('Cash','Card','EFT','Bank Transfer')),
    ReferenceNumber VARCHAR(100) NOT NULL UNIQUE,
    CONSTRAINT FK_Payment_Employee FOREIGN KEY (EmployeeID) REFERENCES Employee(EmployeeID),
    CONSTRAINT FK_Payment_Invoice FOREIGN KEY (InvoiceID) REFERENCES Invoice(InvoiceID)
);
GO

CREATE TABLE Vehicle (
    VehicleID INT IDENTITY(1,1) PRIMARY KEY,
    VehicleType VARCHAR(50) NOT NULL,
    Capacity DECIMAL(10,2) NOT NULL CHECK (Capacity > 0),
    RegistrationNumber VARCHAR(20) NOT NULL UNIQUE,
    Status VARCHAR(30) NOT NULL CHECK (Status IN ('Available','In Use','Maintenance')),
    LastServiceDate DATE NULL,
    YearOfManufacture INT NOT NULL CHECK (YearOfManufacture >= 1990)
);
GO

CREATE TABLE Driver (
    DriverID INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeID INT NOT NULL UNIQUE,
    LicenseExpiry DATE NOT NULL,
    LicenseClass VARCHAR(10) NOT NULL,
    CONSTRAINT FK_Driver_Employee FOREIGN KEY (EmployeeID) REFERENCES Employee(EmployeeID)
);
GO

CREATE TABLE Route (
    RouteID INT IDENTITY(1,1) PRIMARY KEY,
    StartLocation VARCHAR(150) NOT NULL,
    EndLocation VARCHAR(150) NOT NULL,
    Distance DECIMAL(8,2) NOT NULL CHECK (Distance > 0),
    EstimatedDurationMinutes INT NOT NULL CHECK (EstimatedDurationMinutes > 0),
    RouteDescription VARCHAR(255) NULL
);
GO

CREATE TABLE Delivery (
    DeliveryID INT IDENTITY(1,1) PRIMARY KEY,
    OrderID INT NOT NULL,
    VehicleID INT NOT NULL,
    DriverID INT NOT NULL,
    RouteID INT NOT NULL,
    ScheduledDate DATETIME NOT NULL,
    ActualDeliveryDate DATETIME NULL,
    Status VARCHAR(30) NOT NULL CHECK (Status IN ('Scheduled','In Transit','Delivered','Delayed','Cancelled')),
    CONSTRAINT FK_Delivery_Order FOREIGN KEY (OrderID) REFERENCES [Order](OrderID),
    CONSTRAINT FK_Delivery_Vehicle FOREIGN KEY (VehicleID) REFERENCES Vehicle(VehicleID),
    CONSTRAINT FK_Delivery_Driver FOREIGN KEY (DriverID) REFERENCES Driver(DriverID),
    CONSTRAINT FK_Delivery_Route FOREIGN KEY (RouteID) REFERENCES Route(RouteID)
);
GO

CREATE TABLE ShipmentTracking (
    TrackingID INT IDENTITY(1,1) PRIMARY KEY,
    DeliveryID INT NOT NULL,
    CurrentLocation VARCHAR(200) NOT NULL,
    StatusUpdate VARCHAR(200) NOT NULL,
    [Timestamp] DATETIME NOT NULL DEFAULT GETDATE(),
    GPSCoordinates VARCHAR(50) NULL,
    CONSTRAINT FK_ShipmentTracking_Delivery FOREIGN KEY (DeliveryID) REFERENCES Delivery(DeliveryID)
);
GO


/* ============================================================
   SAMPLE DATA
   ============================================================ */

INSERT INTO Employee
(EmployeeName, Role, Department, ContactNumber, Email, HireDate, Salary)
VALUES
('Thapelo Seepe','Warehouse Manager','Warehouse','0711111111','thapelo@freshharvest.co.za','2023-01-15',28000),
('Foster Mondele','Finance Clerk','Finance','0722222222','foster@freshharvest.co.za','2023-03-10',22000),
('Ofentse Setshedi','Driver','Logistics','0733333333','ofentse@freshharvest.co.za','2022-06-01',18000),
('Wazile Molefe','Driver','Logistics','0744444444','wazile@freshharvest.co.za','2022-08-20',18500),
('Tshepang Malinga','Inventory Clerk','Warehouse','0755555555','tshepang@freshharvest.co.za','2024-02-01',16000),
('Masungulo Ngobeni','Operations Supervisor','Operations','0766666666','masungulo@freshharvest.co.za','2023-05-12',25000);
GO

INSERT INTO Supplier
(SupplierName, ContactNumber, Email, Address, RegistrationNo, ActiveStatus)
VALUES
('AgriSupply SA','0111112222','info@agrisupply.co.za','Johannesburg, Gauteng','REG001',1),
('GreenFarm Suppliers','0113334444','sales@greenfarm.co.za','Pretoria, Gauteng','REG002',1),
('Cape Fresh Produce','0215556666','orders@capefresh.co.za','Cape Town, Western Cape','REG003',1);
GO

INSERT INTO Farmer
(FarmerName, FarmLocation, ContactNumber, Email, FarmSizeHectares)
VALUES
('Mpho Farm','Limpopo','0821001001','mpho@farm.co.za',80.50),
('Sunrise Valley Farm','Mpumalanga','0821001002','sunrise@farm.co.za',120.00),
('Orange Grove Farm','Western Cape','0821001003','orange@farm.co.za',65.25);
GO

INSERT INTO SupplierFarmer
(SupplierID, FarmerID, ContractStartDate, ContractEndDate)
VALUES
(1,1,'2025-01-01','2026-12-31'),
(2,2,'2025-02-01','2026-12-31'),
(3,3,'2025-03-01','2026-12-31');
GO

INSERT INTO ProductCategory
(CategoryName, StorageRequirement, HandlingInstructions)
VALUES
('Leafy Greens','Cold Storage','Keep refrigerated and avoid direct sunlight'),
('Citrus Fruits','Cool Dry Storage','Keep dry and avoid bruising'),
('Root Vegetables','Dry Storage','Store in ventilated dry area'),
('Fresh Herbs','Cold Storage','Keep refrigerated and handle carefully');
GO

INSERT INTO Product
(CategoryID, ProductName, UnitPrice, ShelfLifeDays, Unit)
VALUES
(1,'Spinach',18.50,5,'kg'),
(1,'Lettuce',15.00,4,'kg'),
(2,'Oranges',22.00,14,'kg'),
(3,'Potatoes',12.50,30,'kg'),
(4,'Coriander',10.00,3,'bundle');
GO

INSERT INTO Batch
(FarmerID, SupplierID, ArrivalDate, TotalQuantity, QualityStatus, ExpiryDate)
VALUES
(1,1,'2026-05-01',500,'Accepted','2026-05-08'),
(2,2,'2026-05-02',800,'Accepted','2026-05-16'),
(3,3,'2026-05-03',600,'Pending Inspection','2026-05-20');
GO

INSERT INTO BatchProduct
(BatchID, ProductID, Quantity, UnitCost)
VALUES
(1,1,250,12.00),
(1,2,250,10.00),
(2,3,500,15.00),
(2,4,300,8.00),
(3,5,200,6.00);
GO

INSERT INTO Warehouse
(EmployeeID, Location, TotalCapacity, ContactNumber)
VALUES
(1,'Johannesburg Distribution Centre',5000,'0119001000'),
(5,'Pretoria Cold Storage',3500,'0129002000');
GO

INSERT INTO SectionType
(SectionType, DefaultTempZone, HandlingNotes)
VALUES
('Cold','2-8 Degrees Celsius','Used for leafy greens and herbs'),
('Dry','Room Temperature','Used for potatoes and dry produce'),
('Cool Dry','10-15 Degrees Celsius','Used for citrus fruits');
GO

INSERT INTO StorageSection
(WarehouseID, SectionTypeID, Capacity, CurrentOccupancy)
VALUES
(1,1,1500,700),
(1,2,2000,800),
(2,3,1200,500);
GO

INSERT INTO Inventory
(SectionID, ProductID, QuantityAvailable, LastUpdated, MinStockLevel, MaxStockLevel)
VALUES
(1,1,250,GETDATE(),50,500),
(1,2,200,GETDATE(),50,500),
(3,3,450,GETDATE(),100,1000),
(2,4,300,GETDATE(),100,1000),
(1,5,120,GETDATE(),30,300);
GO

INSERT INTO Equipment
(WarehouseID, EquipmentName, EquipmentType, PurchaseDate, LastMaintenanceDate)
VALUES
(1,'Forklift A','Forklift','2023-01-10','2026-03-01'),
(1,'Cooling Unit 1','Cooling Unit','2022-06-20','2026-04-15'),
(2,'Pallet Jack B','Pallet Jack','2024-02-12','2026-02-20');
GO

INSERT INTO Customer
(CustomerName, ContactNumber, Address, Email, CustomerType, RegistrationDate)
VALUES
('FreshMart Retailers','0101112222','Sandton, Johannesburg','orders@freshmart.co.za','Retailer','2025-01-12'),
('Urban Foods','0103334444','Midrand, Johannesburg','buy@urbanfoods.co.za','Wholesaler','2025-03-18'),
('Export Fresh SA','0105556666','Cape Town Harbour','info@exportfresh.co.za','Exporter','2025-05-01');
GO




INSERT INTO [Order]
(CustomerID, OrderDate, Status, DeliveryAddress, Notes)
VALUES
(1,'2026-05-05','Processing','Sandton, Johannesburg','Deliver before 10 AM'),
(2,'2026-05-06','Pending','Midrand, Johannesburg','Call before delivery'),
(3,'2026-05-07','Dispatched','Cape Town Harbour','Export packaging required'),
(1,'2025-01-20','Delivered','Sandton, Johannesburg','Historical transaction 2025-Q1-01'),
(2,'2025-03-25','Delivered','Midrand, Johannesburg','Historical transaction 2025-Q1-02'),
(1,'2025-04-18','Processing','Sandton, Johannesburg','Historical transaction 2025-Q2-01'),
(3,'2025-06-12','Delivered','Cape Town Harbour','Historical transaction 2025-Q2-02'),
(2,'2025-07-22','Delivered','Midrand, Johannesburg','Historical transaction 2025-Q3-01'),
(1,'2025-09-10','Dispatched','Sandton, Johannesburg','Historical transaction 2025-Q3-02'),
(3,'2025-10-14','Delivered','Cape Town Harbour','Historical transaction 2025-Q4-01'),
(1,'2025-12-05','Delivered','Sandton, Johannesburg','Historical transaction 2025-Q4-02'),
(2,'2026-01-15','Delivered','Midrand, Johannesburg','Historical transaction 2026-Q1-01'),
(1,'2026-02-11','Delivered','Sandton, Johannesburg','Historical transaction 2026-Q1-02'),
(3,'2026-03-19','Delivered','Cape Town Harbour','Historical transaction 2026-Q1-03'),
(1,'2026-04-08','Processing','Sandton, Johannesburg','Historical transaction 2026-Q2-01'),
(2,'2026-06-17','Delivered','Midrand, Johannesburg','Historical transaction 2026-Q2-02'),
(3,'2026-07-09','Dispatched','Cape Town Harbour','Historical transaction 2026-Q3-01'),
(1,'2026-08-21','Delivered','Sandton, Johannesburg','Historical transaction 2026-Q3-02'),
(2,'2026-09-16','Pending','Midrand, Johannesburg','Historical transaction 2026-Q3-03'),
(3,'2026-10-13','Delivered','Cape Town Harbour','Historical transaction 2026-Q4-01'),
(1,'2026-11-18','Delivered','Sandton, Johannesburg','Historical transaction 2026-Q4-02'),
(2,'2026-12-10','Delivered','Midrand, Johannesburg','Historical transaction 2026-Q4-03');
GO

INSERT INTO OrderItem
(OrderID, ProductID, Quantity, UnitPrice)
VALUES
(1,1,100,18.50),
(1,3,150,22.00),
(2,4,200,12.50),
(2,5,50,10.00),
(3,3,250,22.00),
(4,3,120,22.00),
(4,1,60,18.50),
(5,4,180,12.50),
(5,5,40,10.00),
(6,3,140,22.00),
(7,3,300,22.00),
(7,4,100,12.50),
(8,4,240,12.50),
(8,2,80,15.00),
(9,1,130,18.50),
(9,3,90,22.00),
(10,3,350,22.00),
(11,2,160,15.00),
(11,5,70,10.00),
(12,4,220,12.50),
(12,1,100,18.50),
(13,3,180,22.00),
(13,2,90,15.00),
(14,3,280,22.00),
(14,4,120,12.50),
(15,1,150,18.50),
(15,5,60,10.00),
(16,4,260,12.50),
(16,2,100,15.00),
(17,3,320,22.00),
(17,5,80,10.00),
(18,1,170,18.50),
(18,3,110,22.00),
(19,4,190,12.50),
(19,2,120,15.00),
(20,3,400,22.00),
(20,4,100,12.50),
(21,1,200,18.50),
(21,5,100,10.00),
(22,4,300,12.50),
(22,3,150,22.00);
GO

INSERT INTO TaxRate
(RatePercent, EffectiveDate, Description)
VALUES
(15.00,'2026-01-01','Standard VAT rate - 2026'),
(15.00,'2025-01-01','Standard VAT rate - 2025');
GO

INSERT INTO Invoice
(OrderID, TaxRateID, TotalAmount, IssueDate, DueDate, PaymentStatus)
VALUES
(1,1,5922.50,'2026-05-05','2026-05-20','Partially Paid'),
(2,1,3450.00,'2026-05-06','2026-05-21','Unpaid'),
(3,1,6325.00,'2026-05-07','2026-05-22','Paid'),
(4,2,4312.50,'2025-01-20','2025-02-04','Paid'),
(5,2,3047.50,'2025-03-25','2025-04-09','Partially Paid'),
(6,2,3542.00,'2025-04-18','2025-05-03','Unpaid'),
(7,2,9027.50,'2025-06-12','2025-06-27','Paid'),
(8,2,4830.00,'2025-07-22','2025-08-06','Paid'),
(9,2,5042.75,'2025-09-10','2025-09-25','Partially Paid'),
(10,2,8855.00,'2025-10-14','2025-10-29','Paid'),
(11,2,3565.00,'2025-12-05','2025-12-20','Unpaid'),
(12,1,5290.00,'2026-01-15','2026-01-30','Paid'),
(13,1,6106.50,'2026-02-11','2026-02-26','Paid'),
(14,1,8809.00,'2026-03-19','2026-04-03','Partially Paid'),
(15,1,3881.25,'2026-04-08','2026-04-23','Unpaid'),
(16,1,5462.50,'2026-06-17','2026-07-02','Paid'),
(17,1,9016.00,'2026-07-09','2026-07-24','Partially Paid'),
(18,1,6399.75,'2026-08-21','2026-09-05','Paid'),
(19,1,4801.25,'2026-09-16','2026-10-01','Unpaid'),
(20,1,11557.50,'2026-10-13','2026-10-28','Paid'),
(21,1,5405.00,'2026-11-18','2026-12-03','Partially Paid'),
(22,1,8107.50,'2026-12-10','2026-12-25','Paid');
GO

INSERT INTO Payment
(EmployeeID, InvoiceID, PaymentDate, Amount, PaymentMethod, ReferenceNumber)
VALUES
(2,1,'2026-05-08',3000.00,'EFT','PAY001'),
(2,3,'2026-05-09',6325.00,'Bank Transfer','PAY002'),
(2,4,'2025-01-23',4312.50,'EFT','PAY004'),
(2,5,'2025-03-28',1523.75,'EFT','PAY005'),
(2,7,'2025-06-15',9027.50,'EFT','PAY007'),
(2,8,'2025-07-25',4830.00,'EFT','PAY008'),
(2,9,'2025-09-13',2521.38,'EFT','PAY009'),
(2,10,'2025-10-17',8855.00,'EFT','PAY010'),
(2,12,'2026-01-18',5290.00,'EFT','PAY012'),
(2,13,'2026-02-14',6106.50,'EFT','PAY013'),
(2,14,'2026-03-22',4404.50,'EFT','PAY014'),
(2,16,'2026-06-20',5462.50,'EFT','PAY016'),
(2,17,'2026-07-12',4508.00,'EFT','PAY017'),
(2,18,'2026-08-24',6399.75,'EFT','PAY018'),
(2,20,'2026-10-16',11557.50,'EFT','PAY020'),
(2,21,'2026-11-21',2702.50,'EFT','PAY021'),
(2,22,'2026-12-13',8107.50,'EFT','PAY022');
GO

INSERT INTO Vehicle
(VehicleType, Capacity, RegistrationNumber, Status, LastServiceDate, YearOfManufacture)
VALUES
('Refrigerated Truck',1200,'FH01GP','In Use','2026-04-01',2021),
('Standard Truck',2000,'FH02GP','Available','2026-03-20',2020),
('Refrigerated Van',800,'FH03GP','In Use','2026-04-10',2022);
GO

INSERT INTO Driver
(EmployeeID, LicenseExpiry, LicenseClass)
VALUES
(3,'2028-12-31','EC'),
(4,'2027-11-30','C1');
GO

INSERT INTO Route
(StartLocation, EndLocation, Distance, EstimatedDurationMinutes, RouteDescription)
VALUES
('Johannesburg Distribution Centre','Sandton',25.50,45,'Route to Sandton customer'),
('Johannesburg Distribution Centre','Midrand',35.00,60,'Route to Midrand customer'),
('Pretoria Cold Storage','Cape Town Harbour',1450.00,1080,'Long distance export route');
GO

INSERT INTO Delivery
(OrderID, VehicleID, DriverID, RouteID, ScheduledDate, ActualDeliveryDate, Status)
VALUES
(1,1,1,1,'2026-05-10 08:00',NULL,'In Transit'),
(2,2,2,2,'2026-05-11 09:00',NULL,'Scheduled'),
(3,3,1,3,'2026-05-12 06:00',NULL,'In Transit'),
(4,1,1,1,'2025-01-21 08:00','2025-01-22 10:00','Delivered'),
(5,2,2,2,'2025-03-26 08:00','2025-03-27 10:00','Delivered'),
(6,1,1,1,'2025-04-19 08:00',NULL,'Scheduled'),
(7,3,1,3,'2025-06-13 08:00','2025-06-14 10:00','Delivered'),
(8,2,2,2,'2025-07-23 08:00','2025-07-24 10:00','Delivered'),
(9,1,1,1,'2025-09-11 08:00',NULL,'In Transit'),
(10,3,1,3,'2025-10-15 08:00','2025-10-16 10:00','Delivered'),
(11,1,1,1,'2025-12-06 08:00','2025-12-07 10:00','Delivered'),
(12,2,2,2,'2026-01-16 08:00','2026-01-17 10:00','Delivered'),
(13,1,1,1,'2026-02-12 08:00','2026-02-13 10:00','Delivered'),
(14,3,1,3,'2026-03-20 08:00','2026-03-21 10:00','Delivered'),
(15,1,1,1,'2026-04-09 08:00',NULL,'Scheduled'),
(16,2,2,2,'2026-06-18 08:00','2026-06-19 10:00','Delivered'),
(17,3,1,3,'2026-07-10 08:00',NULL,'In Transit'),
(18,1,1,1,'2026-08-22 08:00','2026-08-23 10:00','Delivered'),
(19,2,2,2,'2026-09-17 08:00',NULL,'Scheduled'),
(20,3,1,3,'2026-10-14 08:00','2026-10-15 10:00','Delivered'),
(21,1,1,1,'2026-11-19 08:00','2026-11-20 10:00','Delivered'),
(22,2,2,2,'2026-12-11 08:00','2026-12-12 10:00','Delivered');
GO

INSERT INTO ShipmentTracking
(DeliveryID, CurrentLocation, StatusUpdate, [Timestamp], GPSCoordinates)
VALUES
(1,'Alexandra Road','Truck departed warehouse','2026-05-10 08:30','-26.1040,28.0560'),
(1,'Sandton','Arriving at customer site','2026-05-10 09:20','-26.1076,28.0567'),
(3,'Bloemfontein','Delivery in transit to Cape Town','2026-05-12 14:00','-29.0852,26.1596');
GO


SELECT * FROM Supplier;
SELECT * FROM Farmer;
SELECT * FROM SupplierFarmer;
SELECT * FROM ProductCategory;
SELECT * FROM Product;
SELECT * FROM Batch;
SELECT * FROM BatchProduct;
SELECT * FROM Warehouse;
SELECT * FROM SectionType;
SELECT * FROM StorageSection;
SELECT * FROM Inventory;
SELECT * FROM Employee;
SELECT * FROM Equipment;
SELECT * FROM Customer;
SELECT * FROM [Order];
SELECT * FROM OrderItem;
SELECT * FROM TaxRate;
SELECT * FROM Invoice;
SELECT * FROM Payment;
SELECT * FROM Vehicle;
SELECT * FROM Driver;
SELECT * FROM Route;
SELECT * FROM Delivery;
SELECT * FROM ShipmentTracking;
GO

SELECT
    YEAR(OrderDate) AS [Year],
    DATEPART(QUARTER, OrderDate) AS [Quarter],
    DATENAME(MONTH, OrderDate) AS [Month],
    COUNT(*) AS NumberOfOrders
FROM [Order]
GROUP BY YEAR(OrderDate), DATEPART(QUARTER, OrderDate), MONTH(OrderDate), DATENAME(MONTH, OrderDate)
ORDER BY YEAR(OrderDate), MONTH(OrderDate);
GO

SELECT
    COUNT(DISTINCT o.OrderID) AS TotalOrders,
    CAST(SUM(oi.Quantity) AS DECIMAL(14,2)) AS TotalQuantitySold,
    CAST(SUM(oi.Quantity * oi.UnitPrice) AS DECIMAL(14,2)) AS TotalSalesRevenue
FROM [Order] o
INNER JOIN OrderItem oi ON oi.OrderID = o.OrderID;
GO
