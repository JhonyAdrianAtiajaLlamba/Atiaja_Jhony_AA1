
-- 1. Eliminar tablas existentes, respetando las relaciones
DROP TABLE IF EXISTS dbo.registros_matricula;
DROP TABLE IF EXISTS dbo.asignaturas;
DROP TABLE IF EXISTS dbo.estudiantes;

-- 2. Crear tablas
CREATE TABLE dbo.estudiantes ( --Apartado para crear la tabla de estudiantes
    estudiante_id INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_estudiantes PRIMARY KEY,
    nombre        VARCHAR(120) NOT NULL,
    cedula        VARCHAR(20)  NOT NULL
        CONSTRAINT UQ_estudiantes_cedula UNIQUE,
    facultad      VARCHAR(120) NOT NULL
);

CREATE TABLE dbo.asignaturas ( --Apartado para crear la tabla de asignaturas
    asignatura_id     INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_asignaturas PRIMARY KEY,
    nombre_materia    VARCHAR(120) NOT NULL
        CONSTRAINT UQ_asignaturas_nombre_materia UNIQUE,
    docente           VARCHAR(120) NOT NULL,
    cupos_disponibles INT NOT NULL
        CONSTRAINT CK_asignaturas_cupos
        CHECK (cupos_disponibles >= 0)
);

CREATE TABLE dbo.registros_matricula ( --Apartado para crear la tabla de registros de matricula
    registro_id    INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_registros_matricula PRIMARY KEY,
    estudiante_id INT NOT NULL,
    asignatura_id INT NOT NULL,
    fecha_registro DATETIMEOFFSET(0) NOT NULL
        CONSTRAINT DF_registros_matricula_fecha
        DEFAULT (SYSDATETIMEOFFSET()),
    estado VARCHAR(10) NOT NULL
        CONSTRAINT CK_registros_matricula_estado
        CHECK (estado IN ('CONFIRMADA', 'PENDIENTE')),

    CONSTRAINT FK_registros_matricula_estudiantes
        FOREIGN KEY (estudiante_id)
        REFERENCES dbo.estudiantes (estudiante_id),

    CONSTRAINT FK_registros_matricula_asignaturas
        FOREIGN KEY (asignatura_id)
        REFERENCES dbo.asignaturas (asignatura_id),

    CONSTRAINT UQ_registros_matricula_estudiante_asignatura
        UNIQUE (estudiante_id, asignatura_id)
);

-- 3. Cargar datos de ejemplo
INSERT INTO dbo.estudiantes (nombre, cedula, facultad) --Apartado para insertar datos de ejemplo en la tabla de estudiantes
VALUES
    ('Ana Torres', '0102030405', 'Ingeniería'),
    ('Luis Mendoza', '1102030406', 'Ciencias Administrativas');

INSERT INTO dbo.asignaturas
    (nombre_materia, docente, cupos_disponibles)
VALUES
    ('Base de Datos', 'Dra. María Salazar', 5),
    ('Programación', 'Ing. Carlos Ruiz', 5),
    ('Sistemas Operativos', 'Msc. Elena Viteri', 5);

-- 4. Transacción A: matricular y descontar un cupo de forma atómica
BEGIN TRY --registro de matricula para el estudiante 1 en la asignatura 1
    BEGIN TRANSACTION;

    UPDATE dbo.asignaturas
    SET cupos_disponibles = cupos_disponibles - 1
    WHERE asignatura_id = 1
      AND cupos_disponibles > 0;

    IF @@ROWCOUNT = 0
        THROW 50001, N'La asignatura no existe o no tiene cupos disponibles.', 1;

    INSERT INTO dbo.registros_matricula
        (estudiante_id, asignatura_id, estado)
    VALUES
        (1, 1, 'CONFIRMADA');

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;

SELECT *
FROM dbo.registros_matricula
WHERE estudiante_id = 1
  AND asignatura_id = 1;

SELECT nombre_materia, cupos_disponibles
FROM dbo.asignaturas
WHERE asignatura_id = 1;

-- 5. Transacción B: demostrar que ROLLBACK deshace la inserción
BEGIN TRANSACTION;

INSERT INTO dbo.registros_matricula -- Apartado para insertar un registro de matrícula en la tabla de registros
    (estudiante_id, asignatura_id, estado)
VALUES
    (2, 1, 'PENDIENTE');

ROLLBACK TRANSACTION;

SELECT *
FROM dbo.registros_matricula
WHERE estudiante_id = 2
  AND asignatura_id = 1;

-- 6. Transacción C: provocar un error controlado y deshacer los cambios
BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE dbo.asignaturas
    SET cupos_disponibles = cupos_disponibles - 1
    WHERE asignatura_id IN (1, 2)
      AND cupos_disponibles > 0;

    UPDATE dbo.asignaturas
    SET cupos_disponibles = cupos_disponibles - 1
    WHERE asignatura_id = 999
      AND cupos_disponibles > 0;

    IF @@ROWCOUNT = 0
        THROW 50002, N'La asignatura 999 no existe; se cancela la transacción.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    PRINT CONCAT(N'Error controlado: ', ERROR_MESSAGE());
END CATCH;

-- Comprobar los cupos después del ROLLBACK
SELECT asignatura_id, nombre_materia, cupos_disponibles -- Apartado para seleccionar los cupos disponibles de las asignaturas
FROM dbo.asignaturas 
ORDER BY asignatura_id;

-- 7. Patrón de matrícula concurrente: confirmar solo si hay cupo
BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE dbo.asignaturas
    SET cupos_disponibles = cupos_disponibles - 1
    WHERE asignatura_id = 3
      AND cupos_disponibles > 0;

    IF @@ROWCOUNT = 0
        THROW 50003, N'No hay cupos disponibles para esa asignatura.', 1;

    INSERT INTO dbo.registros_matricula
        (estudiante_id, asignatura_id, estado)
    VALUES
        (2, 3, 'CONFIRMADA');

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;

-- 8. Verificación final con los registros de matrícula y los cupos disponibles
SELECT
    r.registro_id, -- Apartado para seleccionar los registros de matrícula junto con los nombres de los estudiantes y las asignaturas
    e.nombre AS estudiante,
    a.nombre_materia,
    r.fecha_registro,
    r.estado,
    a.cupos_disponibles
FROM dbo.registros_matricula AS r
INNER JOIN dbo.estudiantes AS e
    ON e.estudiante_id = r.estudiante_id
INNER JOIN dbo.asignaturas AS a
    ON a.asignatura_id = r.asignatura_id
ORDER BY r.registro_id;
--todo el código ha sido creado usando los lineamientos solicitados en el enunciado de la actividad autonoma 1