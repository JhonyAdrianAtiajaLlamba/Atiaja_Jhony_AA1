# Atiaja_Jhony_AA1

Resolución de la actividad autónoma 1 de Administración de bases de datos.

## Entrega

- [Script PostgreSQL](matriculacion_concurrencia.sql): esquema, datos de prueba, transacciones ACID y plantillas de concurrencia.

El informe y el PDF se elaboran aparte en Word. En la primera página del informe debe incluirse el enlace público de GitHub a este archivo SQL.

## Ejecución

```bash
psql -v ON_ERROR_STOP=1 -f matriculacion_concurrencia.sql
```

El script está escrito para PostgreSQL 14 o superior. Las pruebas de aislamiento requieren dos sesiones conectadas a la misma base de datos.
