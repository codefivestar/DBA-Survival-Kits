-- 🖥️ 1. Identificar versión y edición
SELECT SERVERPROPERTY('ServerName') AS ServerName
	, SERVERPROPERTY('InstanceName') AS InstanceName
	, SERVERPROPERTY('ProductVersion') AS ProductVersion
	, SERVERPROPERTY('ProductLevel') AS ProductLevel
	, SERVERPROPERTY('Edition') AS Edition
	, SERVERPROPERTY('EngineEdition') AS EngineEdition;

-- 💾 2. Revisar espacio de las bases de datos
SELECT DB_NAME(database_id) AS DatabaseName
	, SUM(size) * 8.0 / 1024 AS Size_MB
	, SUM(size) * 8.0 / 1024 / 1024 AS Size_GB
FROM sys.master_files
GROUP BY database_id
ORDER BY Size_GB DESC;

-- 🚨 3. Detectar archivos con poco espacio libre
  SELECT DB_NAME(mf.database_id) AS DatabaseName
	   , mf.name AS LogicalFileName
	   , mf.physical_name
	   , mf.type_desc
	   , mf.size * 8.0 / 1024 AS Size_MB
	   , FILEPROPERTY(mf.name, 'SpaceUsed') * 8.0 / 1024 AS Used_MB
	   , (mf.size - FILEPROPERTY(mf.name, 'SpaceUsed')) * 8.0 / 1024 AS Free_MB
    FROM sys.master_files mf
   WHERE mf.type IN (0, 1)
ORDER BY Free_MB ASC;

-- 💽 4. Revisar los últimos backups
   SELECT d.name AS DatabaseName
		, MAX(CASE WHEN bs.type = 'D' THEN bs.backup_finish_date END) AS LastFullBackup
		, MAX(CASE WHEN bs.type = 'I' THEN bs.backup_finish_date END) AS LastDifferentialBackup
		, MAX(CASE WHEN bs.type = 'L' THEN bs.backup_finish_date END) AS LastLogBackup
	 FROM sys.databases d
LEFT JOIN msdb.dbo.backupset bs
	   ON d.name = bs.database_name
 GROUP BY d.name
 ORDER BY d.name;

-- 🔥 5. Encontrar consultas con mayor consumo de CPU
SELECT TOP (10) qs.total_worker_time / 1000 AS TotalCPU_ms
	, qs.execution_count
	, qs.total_worker_time / NULLIF(qs.execution_count, 0) / 1000 AS AvgCPU_ms
	, qs.total_elapsed_time / 1000 AS TotalElapsed_ms
	, DB_NAME(st.dbid) AS DatabaseName
	, SUBSTRING(st.TEXT, (qs.statement_start_offset / 2) + 1, (
			(
				CASE qs.statement_end_offset
					WHEN - 1
						THEN DATALENGTH(st.TEXT)
					ELSE qs.statement_end_offset
					END - qs.statement_start_offset
				) / 2
			) + 1) AS QueryText
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY qs.total_worker_time DESC;

-- 🐌 6. Encontrar consultas más lentas
SELECT TOP (10) qs.execution_count
	, qs.total_elapsed_time / 1000 AS TotalElapsed_ms
	, qs.total_elapsed_time / NULLIF(qs.execution_count, 0) / 1000 AS AvgElapsed_ms
	, qs.total_worker_time / 1000 AS TotalCPU_ms
	, DB_NAME(st.dbid) AS DatabaseName
	, st.TEXT AS QueryText
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY AvgElapsed_ms DESC;

-- 🔒 7. Detectar bloqueos
SELECT r.session_id AS BlockedSessionID
	, r.blocking_session_id AS BlockingSessionID
	, r.STATUS
	, r.wait_type
	, r.wait_time
	, DB_NAME(r.database_id) AS DatabaseName
	, r.command
FROM sys.dm_exec_requests r
WHERE r.blocking_session_id <> 0
ORDER BY r.wait_time DESC;

-- 👥 8. Consultar sesiones activas
SELECT s.session_id
	, s.login_name
	, s.host_name
	, s.program_name
	, s.STATUS
	, s.cpu_time
	, s.memory_usage
	, s.reads
	, s.writes
	, s.login_time
FROM sys.dm_exec_sessions s
WHERE s.is_user_process = 1
ORDER BY s.cpu_time DESC;

-- 📊 9. Identificar índices faltantes
SELECT TOP (20) DB_NAME(mid.database_id) AS DatabaseName
	, OBJECT_SCHEMA_NAME(mid.object_id, mid.database_id) AS SchemaName
	, OBJECT_NAME(mid.object_id, mid.database_id) AS TableName
	, migs.user_seeks
	, migs.user_scans
	, migs.avg_total_user_cost
	, migs.avg_user_impact
	, mid.equality_columns
	, mid.inequality_columns
	, mid.included_columns
FROM sys.dm_db_missing_index_group_stats migs
INNER JOIN sys.dm_db_missing_index_groups mig
	ON migs.group_handle = mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details mid
	ON mig.index_handle = mid.index_handle
ORDER BY migs.avg_user_impact DESC;

-- 🚨 10. Consultar errores del SQL Server Error Log
EXEC sys.xp_readerrorlog 0
	, 1
	, NULL
	, NULL
	, NULL
	, NULL
	, N'desc';

EXEC sys.xp_readerrorlog 0
	, 1
	, N'Error';

EXEC sys.xp_readerrorlog 0
	, 1
	, N'failed';

EXEC sys.xp_readerrorlog 0
	, 1
	, N'login failed';
