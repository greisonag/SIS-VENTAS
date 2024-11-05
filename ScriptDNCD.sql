-- Tabla de Usuarios
CREATE TABLE Usuarios (
    UsuarioID INT PRIMARY KEY IDENTITY(1,1),
    Nombre NVARCHAR(100) NOT NULL,
    Correo NVARCHAR(100) UNIQUE NOT NULL,
    Contrasena NVARCHAR(100) NOT NULL,
    Rol NVARCHAR(50) NOT NULL, -- Ejemplo: 'Administrador', 'Vendedor'
    FechaCreacion DATETIME DEFAULT GETDATE()
);

-- Tabla de Proveedores
CREATE TABLE Proveedores (
    ProveedorID INT PRIMARY KEY IDENTITY(1,1),
    Nombre NVARCHAR(100) NOT NULL,
    Direccion NVARCHAR(200),
    Telefono NVARCHAR(15),
    Correo NVARCHAR(100) UNIQUE,
    FechaRegistro DATETIME DEFAULT GETDATE()
);

-- Tabla de Clientes
CREATE TABLE Clientes (
    ClienteID INT PRIMARY KEY IDENTITY(1,1),
    Nombre NVARCHAR(100) NOT NULL,
    Direccion NVARCHAR(200),
    Telefono NVARCHAR(15),
    Correo NVARCHAR(100) UNIQUE,
    FechaRegistro DATETIME DEFAULT GETDATE()
);

-- Tabla de Inventario
CREATE TABLE Inventario (
    ProductoID INT PRIMARY KEY IDENTITY(1,1),
    Nombre NVARCHAR(100) NOT NULL,
    Descripcion NVARCHAR(255),
    PrecioCosto DECIMAL(18, 2) NOT NULL,
    PrecioVenta DECIMAL(18, 2) NOT NULL,
    StockActual INT DEFAULT 0,
    StockMinimo INT DEFAULT 0,
    FechaIngreso DATETIME DEFAULT GETDATE()
);

-- Tabla de Compras (sin ClienteID)
CREATE TABLE Compras (
    CompraID INT PRIMARY KEY IDENTITY(1,1),
    ProveedorID INT FOREIGN KEY REFERENCES Proveedores(ProveedorID),
    UsuarioID INT FOREIGN KEY REFERENCES Usuarios(UsuarioID),
    FechaCompra DATETIME DEFAULT GETDATE(),
    TotalCompra DECIMAL(18, 2) NOT NULL,
    TipoPago NVARCHAR(50) NOT NULL, -- Ej: 'Contado', 'Crédito'
    Estado NVARCHAR(50) DEFAULT 'Pendiente' -- Ej: 'Pendiente', 'Pagado'
);

-- Tabla de Detalles de Compras
CREATE TABLE DetalleCompras (
    DetalleCompraID INT PRIMARY KEY IDENTITY(1,1),
    CompraID INT FOREIGN KEY REFERENCES Compras(CompraID) ON DELETE CASCADE,
    ProductoID INT FOREIGN KEY REFERENCES Inventario(ProductoID),
    Cantidad INT NOT NULL,
    PrecioUnitario DECIMAL(18, 2) NOT NULL,
    Subtotal AS (Cantidad * PrecioUnitario) -- Campo calculado sin PERSISTED
);


-- Tabla de Ventas (aquí sí incluimos ClienteID)
CREATE TABLE Ventas (
    VentaID INT PRIMARY KEY IDENTITY(1,1),
    ClienteID INT FOREIGN KEY REFERENCES Clientes(ClienteID),
    UsuarioID INT FOREIGN KEY REFERENCES Usuarios(UsuarioID),
    FechaVenta DATETIME DEFAULT GETDATE(),
    TotalVenta DECIMAL(18, 2) NOT NULL,
    Descuento DECIMAL(5, 2) DEFAULT 0.00, -- Porcentaje de descuento
    TipoPago NVARCHAR(50) NOT NULL, -- Ej: 'Contado', 'Crédito'
    Estado NVARCHAR(50) DEFAULT 'Pendiente' -- Ej: 'Pendiente', 'Pagado'
);

-- Tabla de Detalles de Ventas
CREATE TABLE DetalleVentas (
    DetalleVentaID INT PRIMARY KEY IDENTITY(1,1),
    VentaID INT FOREIGN KEY REFERENCES Ventas(VentaID) ON DELETE CASCADE,
    ProductoID INT FOREIGN KEY REFERENCES Inventario(ProductoID),
    Cantidad INT NOT NULL,
    PrecioUnitario DECIMAL(18, 2) NOT NULL,
    Subtotal AS (Cantidad * PrecioUnitario) -- Campo calculado sin PERSISTED
);

-- Tabla de Cuentas por Pagar (para las compras a crédito)
CREATE TABLE CuentasPorPagar (
    CuentaPagarID INT PRIMARY KEY IDENTITY(1,1),
    ProveedorID INT FOREIGN KEY REFERENCES Proveedores(ProveedorID),
    CompraID INT FOREIGN KEY REFERENCES Compras(CompraID),
    Monto DECIMAL(18, 2) NOT NULL,
    FechaEmision DATETIME DEFAULT GETDATE(),
    FechaVencimiento DATETIME NOT NULL,
    Estado NVARCHAR(50) DEFAULT 'Pendiente' -- Ej: 'Pendiente', 'Pagado'
);

-- Tabla de Cuentas por Cobrar (para las ventas a crédito)
CREATE TABLE CuentasPorCobrar (
    CuentaCobrarID INT PRIMARY KEY IDENTITY(1,1),
    ClienteID INT FOREIGN KEY REFERENCES Clientes(ClienteID),
    VentaID INT FOREIGN KEY REFERENCES Ventas(VentaID),
    Monto DECIMAL(18, 2) NOT NULL,
    FechaEmision DATETIME DEFAULT GETDATE(),
    FechaVencimiento DATETIME NOT NULL,
    Estado NVARCHAR(50) DEFAULT 'Pendiente' -- Ej: 'Pendiente', 'Pagado'
);

-- Trigger para actualizar el inventario al realizar una compra
CREATE TRIGGER tr_AfterInsertDetalleCompras
ON DetalleCompras
AFTER INSERT
AS
BEGIN
    UPDATE Inventario
    SET StockActual = StockActual + i.Cantidad
    FROM Inventario inv
    INNER JOIN inserted i ON inv.ProductoID = i.ProductoID
END;

-- Trigger para actualizar el inventario al realizar una venta, asegurando que StockActual no sea negativo
CREATE TRIGGER tr_AfterInsertDetalleVentas
ON DetalleVentas
AFTER INSERT
AS
BEGIN
    UPDATE Inventario
    SET StockActual = CASE 
        WHEN StockActual >= i.Cantidad THEN StockActual - i.Cantidad
        ELSE StockActual 
    END
    FROM Inventario inv
    INNER JOIN inserted i ON inv.ProductoID = i.ProductoID;
END;


CREATE TRIGGER tr_AfterInsertCompras
ON Compras
AFTER INSERT
AS
BEGIN
    INSERT INTO CuentasPorPagar (ProveedorID, CompraID, Monto, FechaEmision, FechaVencimiento, Estado)
    SELECT 
        ProveedorID, 
        CompraID, 
        TotalCompra, 
        GETDATE(), 
        DATEADD(DAY, 30, GETDATE()), 
        'Pendiente'
    FROM inserted
    WHERE TipoPago = 'Crédito';
END;


CREATE TRIGGER tr_AfterInsertVentas
ON Ventas
AFTER INSERT
AS
BEGIN
    INSERT INTO CuentasPorCobrar (ClienteID, VentaID, Monto, FechaEmision, FechaVencimiento, Estado)
    SELECT 
        ClienteID, 
        VentaID, 
        TotalVenta, 
        GETDATE(), 
        DATEADD(DAY, 30, GETDATE()), 
        'Pendiente'
    FROM inserted
    WHERE TipoPago = 'Crédito';
END;
