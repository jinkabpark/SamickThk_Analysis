--  @file   : CreateDB_File.sql
--  @author : JK Park
--  @desc   
--     2024-06-01 최초생성
--                삼익THK 분석실 Project, 김구정부장 DB_V1.0_01.Make_FileGroup.sql 이용하여 수정    
--     2024-06-?? Update By 박준후
--                File 생성절처 Sql 부분 추가
--
--
--	@todo
--		1. 폴더를 미리 생성해야 한다. 김구정
--		2. CREATE DATABASE 문과 하나의 배치로 모든 파일그룹을 생성해야 한다. 김구정
--		3. 파샬그룹은 디비를 선택한 후 '새 쿼리' 로 창을 새로 띄워 실행한다. 김구정

--  @데이터베이스 생성 순서:
--		1. 폴더를 경로에 맞추어 생성한다.
--		2. ssms 에 관리자(윈도우)로 로그인 한다.
--		3. 시스템데이터베이스.master에 새쿼리를 생성한다.
--		4. master에 spTableGroupCreate와 spTablePartitionCreate를 생성한다.
--		5. 이하 쿼리문을 실행한다.
--		6. 생성된 데이터베이스를 선택하고 새쿼리를 연다.
--		7. spTablePartitionCreate 을 생성한다.
--		8. 그룹 파샬 쿼리를 실행한다.

CREATE DATABASE SamickTHK_Analysis

-- ========================================================================================
--  1. 구분 : Master
-- ========================================================================================
EXEC spTableGroupCreate 'SamickTHK_Analysis', 'Master',       'D:\SamickTHK_DB\Maria\Master',    '10MB',  '10MB'
EXEC spTableGroupCreate 'SamickTHK_Analysis', 'MasterIdx',    'D:\SamickTHK_DB\Maria\MasterIdx', '10MB',  '10MB'

-- ========================================================================================
--  2. 구분 : Process
-- ========================================================================================
EXEC spTableGroupCreate 'SamickTHK_Analysis', 'Process',      'D:\SamickTHK_DB\Maria\Process',   '100MB', '10MB'
EXEC spTableGroupCreate 'SamickTHK_Analysis', 'ProcessIdx',   'D:\SamickTHK_DB\Maria\ProcessIdx','100MB', '10MB'

-- ========================================================================================
--  3. 구분 : History
-- ========================================================================================
EXEC spTableGroupCreate 'SamickTHK_Analysis', 'History',      'D:\SamickTHK_DB\Maria\History',   '100MB', '10MB'
EXEC spTableGroupCreate 'SamickTHK_Analysis', 'HistoryIdx',   'D:\SamickTHK_DB\Maria\HistoryIdx','100MB', '10MB'
	
-- ========================================================================================
--  구분 : FileGroup생성 SP
-- ========================================================================================
GO
CREATE OR ALTER PROCEDURE spTableGroupCreate
	@as_database_name   VARCHAR(30),
	@as_filegroup       VARCHAR(30),
	@as_file_filepath   VARCHAR(1000),
	@as_file_size		VARCHAR(10),
    @as_file_growth     VARCHAR(10)
	--@on_ret_num                 INT           OUTPUT,   -- Error Number
	--@os_ret_msg                 VARCHAR(100)  OUTPUT    -- Error Message
AS
BEGIN TRY
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    --SET LOCK_TIMEOUT 10000;
	-- Declare Variables
	DECLARE @s_debug        VARCHAR(100)    -- Debug String
	DECLARE @s_arguments    VARCHAR(100)    -- Argument Data
	DECLARE @n_error_num    INT             -- Error Number : Return Value
	DECLARE @s_error_msg    NVARCHAR(200)   -- Error Message

    DECLARE @strSQL VARCHAR(MAX);
    DECLARE @n_part_idx_y       INT
    DECLARE @n_part_idx_mm      INT

    DECLARE @s_part_index       VARCHAR(10)

    -- Default 파일그룹/파일 생성
	--IF @as_is_create = 'CREATE'
	BEGIN
		-- 파일 그룹 생성
		SET @strSQL = 'ALTER DATABASE ' + @as_database_name + ' ADD FILEGROUP ' + @as_filegroup
		PRINT @strSQL
		EXEC (@strSQL)	-- ***** EXEC
    
		-- 파일 생성
		SET @strSQL = 'ALTER DATABASE ' + @as_database_name 
					+ ' ADD FILE ( NAME = ' + @as_filegroup
					+ '          , FILENAME = "' + @as_file_filepath + '\' + @as_filegroup + '.ndf"'
					+ '          , SIZE = ' + @as_file_size
					+ '          , MAXSIZE = UNLIMITED, FILEGROWTH = ' + @as_file_growth
					+ '          ) TO FILEGROUP ' + @as_filegroup
  
		PRINT @strSQL
		EXEC (@strSQL)	-- ***** EXEC
	END
    

-- Return Success --
EXIT_PROCESS:
	PRINT 'OK'
   --SELECT @on_ret_num = 0
   --SELECT @os_ret_msg = ''
   --RETURN (0);

-- Error Process
ERROR_PROCESS:
   SELECT @s_error_msg = @s_error_msg + @s_arguments
   PRINT  '[' + @s_debug + '] ' + '[' + STR(@n_error_num) + '] ' + @s_error_msg
   --EXEC   sp_log_error 'PROCEDURE', 'spTableGroupCreate', @s_debug, @n_error_num, @s_error_msg
   --SELECT @on_ret_num = @n_error_num
   --SELECT @os_ret_msg = @s_error_msg
   --RETURN @n_error_num;

END TRY

-- Exception
BEGIN CATCH
   SELECT @n_error_num = ERROR_NUMBER()
   SELECT @s_error_msg = ERROR_MESSAGE()
   SELECT @s_error_msg = @s_error_msg + @s_arguments
   PRINT  '[' + @s_debug + '] ' + '[' + STR(@n_error_num) + '] ' + @s_error_msg
   ----EXEC   sp_log_error 'PROCEDURE', 'spTableGroupCreate', @s_debug, @n_error_num, @s_error_msg
   --SELECT @on_ret_num = @n_error_num
   --SELECT @os_ret_msg = @s_error_msg
   --RETURN @n_error_num
END CATCH
