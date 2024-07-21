============================================================================ 
file name   : sp_SamickAnalysis.sql
author      : JK Park
desc   
   1.    2024-06-06 최초생성
   2.    2024-07-06 장비별 stored procedure 추가

token관련 stored procedure

901. spUpdateStatusAtEquipment        장비상태를 변경한다. (Idle-->Run, Run-->Idle)
904. spRequestStatusAtEquipment       장비상태를 가져온다
905. spRetrieveAllEquipmentStatuses   모든 장비상태를 가져온다

921. spLoadReqAtEquipment             장비에서 LoadReq event에 대한 처리 (Dispatcher 반송인식 및 요청 event)
922. spLoadCompAtEquipment            장비에서 LoadComp event에 대한 처리
923. spUnloadReqAtEquipment           장비에서 UnloadReq event에 대한 처리 (Dispatcher 반송인식 및 요청 event)
924. spUnloadCompAtEquipment          장비에서 UnloadComp event에 대한 처리
925. spLoadComp4BottleAtEquipment     Bottle에서 LoadComp event에 대한 처리
926. spUnloadComp4BottleAtEquipment   Bottle에서 UnloadComp event에 대한 처리

931. spRequestBottleData              Bottle 관련 정보를 가져온다
932. spRequestAllBottlesInfoFmEquipment  설비에 있는 모든 Bottle 관련 정보를 가져온다
933. spUpdateBottleStatus             Bottle상태를 임의적으로 수동 변경한다. 정보불일치 발생시 UI에서 사용.
934. spRetrieveAllBottleStatuses      모든 Bottle상태를 가져온다
935. spRetrievePendingBottles         투입대기중인 Bottle정보를 가져온다
936. spRetrieveEmptyBottleCount       설비에서 대기중인 Bottle수량정보를 가져온다
937. spFetchBottleProcessHistory      Bottle에서 수행한 공정이력정보를 가져온다

9A1. spTransferAndDeleteBottle        Bottle 재사용을 위하여 데이터를 Hist로 이동하고 기존 데이터는 삭제한다.
9A2. spFetchNextOperationFromRoute    차기 공정정보를 가져온다
9A3. spUpdateNextOperation            현재공정완료했을때 차기 공정정보 Set한다.

9B1. UpdateNextOper_Insert            LoadComp, UnloadComp에 대한 처리
9B2. ProcessLoadUnloadCompletion      세정후 Bottle 재사용을 위해 분석실 내부 Load Port에 반출입기에 입고될때 기존 Data 삭제하고 History 이동한다
9B3. RetrieveSuitableBottleAtStocker  Stocker에서 Bottle 정보를 가져온다
9B4. UpdateEqpProcessStatus           장비의 Process상태를 변경한다. (LoadReq, LoadComp, UnLoadReq, UnLoadComp, Idle, Pause, Reserve)
9B5. GetTopPriorityBottle             stocker내에 bottle 우선순위, 입고순서로 sotting하여 해당 bottle 정보 출력


이벤트 스케줄러관련 stored procedure
E01.  AggregateDailyEqpStatus         AggregateDailyEqpStatusEvent event scheduler에서 호출
                                    일일가동률 확인을 위해 일일단위로 설비상태정보 집계한다
E02.  MoveOldEqpStatus              MoveOldRecordOfEqp2History event scheduler에서 호출

이벤트 스케줄러 생성
E21.  AggregateDailyEqpStatusEvent    장비상태를 1일 단위 집계하여 summary table(tDailyEqpStatus) 저장한다.
E22.  MoveOldRecordOfEqp2History      tChgEqpStatus table 오래된 record를 tHisChgEqpStatus table로 이동
E23.  CleanupOldRecordsOfTbl          tDailyEqpStatus, tHisProcBotOper, tHisChgEqpStatus history table에서 오래된 record 삭제
============================================================================ 
-- GPT prompt
--     - maria db를 사용하고 있고, c# 에서 stored procedure 호출하는 방법은 ?
--     - static string CallStoredProcedure(string connectionString) 부분수정해줘. stored procedure 명 "spRequestStatusAtStocker2DB"을 parameter 넘기는 방식으로 수정해줘.
--
-- C# 호출방법 사용법
-- using System;
-- using System.Data;
-- using MySql.Data.MySqlClient;

-- class Program
-- {
--     static void Main()
--     {
--         string connectionString = "Server=your_server;Database=your_database;User=your_username;Password=your_password;";
--         string storedProcedureName = "spRequestStatusAtStocker2DB";
--         string resultJson = CallStoredProcedure(connectionString, storedProcedureName);
-- 
--         Console.WriteLine("Output JSON:");
--         Console.WriteLine(resultJson);
--     }

--     static string CallStoredProcedure(string connectionString, string storedProcedureName)
--     {
--         using (MySqlConnection conn = new MySqlConnection(connectionString))
--         {
--             using (MySqlCommand cmd = new MySqlCommand(storedProcedureName, conn))
--             {
--                 cmd.CommandType = CommandType.StoredProcedure;
-- 
--                 conn.Open();
-- 
--                 using (MySqlDataReader reader = cmd.ExecuteReader())
--                 {
--                     if (reader.Read())
--                     {
--                         return reader["result"].ToString();
--                     }
--                 }
--             }
--         }
--         return null;
--     }
-- }
============================================================================ 

-- 101. 장비상태변경시 보고. 장비자체에서 발생하는 Event 보고
-- GPT prompt
-- 1. 입력 파라메터는 json type. 내용은 아래와 같음.
--      {
--         "FmNode" : "InOutBottle"
--         "ToNode" : "DB_Manager" Or "Dispatcher" Or "UI_Manager"
--         "EqpStatus" : "PowerOn"       // PowerOn, Run, Idle, Maintenance
--      }
--    입력 파라메터에 "EqpSeqNo" 정의되어 있지 않으면 '1' 세팅하고 있으면 그 값을 읽어줘.
--    FmNode의 값 "InOutBottle"을 fGetEqpGroupID_FmParameterValue 입력값으로 함수를 실행해서 결과치를 받아줘.
--    CREATE TABLE tMstEqp (
--       EqpGroupID               CHAR(1) NOT NULL,       -- 설비군ID
--       EqpSeqNo                 TINYINT NOT NULL,       -- 호기 (1부터 시작)
--       ...
--       EqpStatus                NVARCHAR(10),           -- 장비상태 (PowerOn, PowerOff, Reserve, Ready, Run, Idle, Pause, Trouble:통신불가, Maintenance, Waiting)
--    }
--    EqpStatus 읽은 값을 이용하여 update 해줘.
--       maria db를 사용하고 있고, 예외 처리를 위한 DECLARE ... HANDLER 구문추가해줘.
-- 2. return_value 변수명을 eqp_group_id로 변경해줘.
-- 3. Error table을 만들고 error 발생하면 관련내용을 insert해줘.
-- 4. Error table에 stored procedure 이름도 추가해서 처리해줘.
-- 5. table명을 tProcSqlError로 변경하고 error code로 추가해서 처리해줘.
--
DELIMITER //
CREATE PROCEDURE spReportChangedEqpStatus(
    IN json_param JSON
)
BEGIN
    DECLARE eqp_group_id CHAR(1) DEFAULT '0';
    DECLARE eqp_seq_no TINYINT DEFAULT 1;
    DECLARE fm_node VARCHAR(20);
    DECLARE eqp_status NVARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- 예외 발생 시 에러 내용을 tProcSqlError 테이블에 삽입
        DECLARE error_message VARCHAR(255);
        DECLARE error_code INT;
        GET DIAGNOSTICS CONDITION 1
            error_message = MESSAGE_TEXT, 
            error_code = MYSQL_ERRNO;
        INSERT INTO tProcSqlError (ProcedureName, ErrorCode, ErrorMessage) 
        VALUES ('spReportChangedEqpStatus', error_code, error_message);
    END;

    -- JSON 파싱
    SET fm_node = JSON_UNQUOTE(JSON_EXTRACT(json_param, '$.FmNode'));
    SET eqp_status = JSON_UNQUOTE(JSON_EXTRACT(json_param, '$.EqpStatus'));
    
    -- EqpSeqNo 존재 여부 확인 및 설정
    IF JSON_CONTAINS_PATH(json_param, 'one', '$.EqpSeqNo') THEN
        SET eqp_seq_no = JSON_UNQUOTE(JSON_EXTRACT(json_param, '$.EqpSeqNo'));
    END IF;
    
    -- FmNode 값을 기반으로 EqpGroupID 설정
    SET eqp_group_id = fGetEqpGroupID_FmParameterValue(fm_node);
    
    -- 서브 프로시저를 호출하여 EqpStatus 업데이트
    CALL spUpdateEqpStatus_MstEqp(eqp_group_id, eqp_seq_no, eqp_status);
END //
DELIMITER ;

-- 102. 반출입기 장비상태를 변경. 컨트롤러 통신하면서 통신이 안될때는 Trouble로 상태변경 요청한다. 사용자 화면에서 설비상태 변경할때 사용.
-- GPT prompt
-- 1. 입력 파라메터는 json type. 내용은 아래와 같음.
--       {
--          "FmNode" : "Dispatcher" Or "UI_Manager"
--          "ToNode" : "DB_Manager"
--          "EqpGroupID" : 1,
--          "EqpSeqNo" : 1,
--          "EqpStatus" : "Reserve"       // Reserve, Trouble, Maintenance
--       }
-- 입력 파라메터에 "EqpSeqNo" 정의되어 있지 않으면 '1' 세팅하고 있으면 그 값을 읽어줘.
-- tMstEqp table의 EqpStatus를 update하는 stored procedure 만들어줘.
-- Return  json type. 내용은 아래와 같음.
--       {
--          "status_code" : 200,            // sql error code
--          "sender_controller" : "DB_Manager"  // 송신메세지의 ToNode값
--          "error_msg" : "None"
--       }
-- 2. eqp_group_id는 입력파라메터에서 읽어줘.
DELIMITER //
CREATE PROCEDURE spChangeEqpStatus(
    IN json_param JSON,
    OUT result JSON
)
BEGIN
    DECLARE eqp_group_id CHAR(1);
    DECLARE eqp_seq_no TINYINT DEFAULT 1;
    DECLARE fm_node VARCHAR(20);
    DECLARE to_node VARCHAR(20);
    DECLARE eqp_status NVARCHAR(10);
    DECLARE error_message VARCHAR(255) DEFAULT 'None';
    DECLARE error_code INT DEFAULT 200;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- 예외 발생 시 에러 내용을 tProcSqlError 테이블에 삽입하고 JSON 결과 설정
        GET DIAGNOSTICS CONDITION 1
            error_message = MESSAGE_TEXT, 
            error_code = MYSQL_ERRNO;
        INSERT INTO tProcSqlError (ProcedureName, ErrorCode, ErrorMessage) VALUES ('spChangeEqpStatus', error_code, error_message);
        SET result = JSON_OBJECT(
            'status_code', error_code,
            'sender_controller', JSON_UNQUOTE(JSON_EXTRACT(json_param, '$.ToNode')),
            'error_msg', error_message
        );
    END;

    -- JSON 파싱
    SET fm_node = JSON_UNQUOTE(JSON_EXTRACT(json_param, '$.FmNode'));
    SET to_node = JSON_UNQUOTE(JSON_EXTRACT(json_param, '$.ToNode'));
    SET eqp_group_id = JSON_UNQUOTE(JSON_EXTRACT(json_param, '$.EqpGroupID'));
    SET eqp_status = JSON_UNQUOTE(JSON_EXTRACT(json_param, '$.EqpStatus'));
    
    -- EqpSeqNo 존재 여부 확인 및 설정
    IF JSON_CONTAINS_PATH(json_param, 'one', '$.EqpSeqNo') THEN
        SET eqp_seq_no = JSON_UNQUOTE(JSON_EXTRACT(json_param, '$.EqpSeqNo'));
    END IF;
    
    -- 서브 프로시저를 호출하여 EqpStatus 업데이트
    CALL spUpdateEqpStatus_MstEqp(eqp_group_id, eqp_seq_no, eqp_status);

    -- 성공 시 JSON 결과 설정
    SET result = JSON_OBJECT(
        'status_code', error_code,
        'sender_controller', to_node,
        'error_msg', error_message
    );
END //
DELIMITER ;

-- 103. 반출입기 설비상태를 요청한다.(sync방식)
-- GPT prompt
-- 1. 입력 파라메터는 json type. 내용은 아래와 같음.
--       {
--          "FmNode" : "Dispatcher" Or "UI_Manager"
--          "ToNode" : "DB_Manager"
--          "EqpSeqNo" : 1,
--          "EqpStatus" : "Reserve"       // Reserve, Trouble, Maintenance
--       }
-- Return  json type. 내용은 아래와 같음.
--       {
--          "status_code" : 200,            // sql error code
--          "sender_controller" : "DB_Manager"  // 송신메세지의 ToNode값
--          "EqpGroupID" : 1,
--          "EqpSeqNo" : 1,
--          "eqp_status" : "PowerOn"       // PowerOn, PowerOff, Reserve, Ready, Run, Idle, Pause, Trouble:통신불가, Maintenance, Waiting
--          "error_msg" : "None"
--       }
-- 입력 파라메터에 "EqpSeqNo" 정의되어 있지 않으면 '1' 세팅하고 있으면 그 값을 읽어줘.
-- tMstEqp table의 EqpStatus를 읽고 eqp_status값으로 return 하는 stored procedure 만들어줘.
-- maria db를 사용하고 있고, 예외 처리를 위한 DECLARE ... HANDLER 구문추가해줘.
-- 2. 예외 발생 시 에러 내용을 tProcSqlError 테이블에 삽입 추가해줘
DELIMITER //
CREATE PROCEDURE spRequestStatus(IN jsonInput JSON, OUT jsonOutput JSON)
BEGIN
    DECLARE v_EqpSeqNo INT DEFAULT 1;
    DECLARE v_EqpGroupID INT;
    DECLARE v_FmNode VARCHAR(50);
    DECLARE v_ToNode VARCHAR(50);
    DECLARE v_EqpStatus VARCHAR(50);
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_ErrorMsg VARCHAR(255) DEFAULT 'None';
    DECLARE v_ErrorText VARCHAR(255);
    DECLARE v_ErrorCode INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_ErrorText = MESSAGE_TEXT;
        GET DIAGNOSTICS CONDITION 1 v_ErrorCode = MYSQL_ERRNO;

        SET v_StatusCode = 500;
        SET v_ErrorMsg = 'Database error';

        -- Insert error details into tProcSqlError table
        INSERT INTO tProcSqlError (ProcedureName, ErrorCode, ErrorMessage) 
        VALUES ('spRequestStatus', v_ErrorCode, v_ErrorText);

        SET jsonOutput = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_ToNode,
            'eqp_status', NULL,
            'error_msg', v_ErrorMsg
        );
        ROLLBACK;
    END;

    -- Extract values from JSON input
    SET v_FmNode = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.FmNode'));
    SET v_ToNode = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.ToNode'));
    SET v_EqpGroupID = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.EqpGroupID'));

    -- Check if EqpSeqNo is provided, if not set to default 1
    IF JSON_CONTAINS_PATH(jsonInput, 'one', '$.EqpSeqNo') THEN
        SET v_EqpSeqNo = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.EqpSeqNo'));
    END IF;

    -- Query the equipment status
    SELECT EqpStatus INTO v_EqpStatus
    FROM tMstEqp
    WHERE EqpGroupID = v_EqpGroupID AND EqpSeqNo = v_EqpSeqNo;

    -- Set the JSON output
    SET jsonOutput = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_ToNode,
        'eqp_status', v_EqpStatus,
        'error_msg', v_ErrorMsg
    );

END //
DELIMITER ;

-- 104-2. 반출입기 설비상태요청에 응답한다.
spRequestStatus stored procedure와 동일함.


-- 111. EmptyBottleLoadReqAtWorkingAreaL1(입고)           Port에서 반출입기 빈병 입고요청메세지
-- 112. EmptyBottlePortEventAtWorkingArea(L1 Port)      반출입기 L1(입고) Port에서 빈병 도착완료메세지
-- 113. EmptyBottlePortEventAtWorkingArea(L1 Port)      반출입기 L1(입고) Port에서 빈병 출하요청(UnloadReq)메세지
-- GPT prompt
-- 1. 입력 파라메터는 json type. 내용은 아래와 같음.
--       {
--          "FmNode" : "Dispatcher" Or "UI_Manager"
--          "ToNode" : "DB_Manager"
--       }
-- Return  json type. 내용은 아래와 같음.
--       {
--          "status_code" : 200,            // sql error code
--          "sender_controller" : "Dispatcher" and "DB_Manager"    // 입력파라메터의 ToNode값
--          "error_msg" : "None"
--       }
-- 송신메세지에 EqpGroupID 있으면 EqpGroupID의 Value 읽고, 없으면 FmNode의 Value을
-- 이용하여 함수 fGetEqpGroupID_FmParameterValue 이용하여 읽는다.
-- 입력 파라메터에 "EqpSeqNo" 정의되어 있지 않으면 '1' 세팅하고 있으면 그 값을 읽어줘.
-- tMstEqp table의 field LoadPort_1 값을 'LoadReq'로 수정한다.
-- maria db를 사용하고 있고, 예외 처리를 위한 DECLARE ... HANDLER 구문추가해줘.
-- 2. DECLARE v_EqpGroupID INT;  는 char 1 byte 변경해줘.
-- 3. 입력 파라메터에 "PortEvent" : "LoadReq" 추가하고 이 값을 LoadPort_1 값을 set할때 사용해줘.
DELIMITER //
CREATE PROCEDURE spEmptyBottlePortEventAtWorkingArea(IN jsonInput JSON, OUT jsonOutput JSON)
BEGIN
    DECLARE v_EqpSeqNo INT DEFAULT 1;
    DECLARE v_EqpGroupID CHAR(1);
    DECLARE v_FmNode VARCHAR(50);
    DECLARE v_ToNode VARCHAR(255);
    DECLARE v_PortEvent VARCHAR(50);
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_ErrorMsg VARCHAR(255) DEFAULT 'None';
    DECLARE v_ErrorText VARCHAR(255);
    DECLARE v_ErrorCode INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_ErrorText = MESSAGE_TEXT;
        GET DIAGNOSTICS CONDITION 1 v_ErrorCode = MYSQL_ERRNO;

        SET v_StatusCode = 500;
        SET v_ErrorMsg = 'Database error';

        -- Insert error details into tProcSqlError table
        INSERT INTO tProcSqlError (ProcedureName, ErrorCode, ErrorMessage) 
        VALUES ('spEmptyBottlePortEventAtWorkingArea', v_ErrorCode, v_ErrorText);

        SET jsonOutput = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_ToNode,
            'error_msg', v_ErrorMsg
        );
        ROLLBACK;
    END;

    -- Extract values from JSON input
    SET v_FmNode = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.FmNode'));
    SET v_ToNode = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.ToNode'));
    SET v_PortEvent = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.PortEvent'));

    -- Check if EqpGroupID is provided, if not use FmNode value with fGetEqpGroupID_FmParameterValue function
    IF JSON_CONTAINS_PATH(jsonInput, 'one', '$.EqpGroupID') THEN
        SET v_EqpGroupID = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.EqpGroupID'));
    ELSE
        SET v_EqpGroupID = fGetEqpGroupID_FmParameterValue(v_FmNode);
    END IF;

    -- Check if EqpSeqNo is provided, if not set to default 1
    IF JSON_CONTAINS_PATH(jsonInput, 'one', '$.EqpSeqNo') THEN
        SET v_EqpSeqNo = CAST(JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.EqpSeqNo')) AS UNSIGNED);
    END IF;

    -- Call the stored procedure to update the tMstEqp table
    CALL spUpdatePortEvent_MstEqp(v_EqpGroupID, v_EqpSeqNo, v_PortEvent, 'LoadPort_1');

    -- Set the JSON output
    SET jsonOutput = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_ToNode,
        'EqpGroupID', v_EqpGroupID,
        'EqpSeqNo', v_EqpSeqNo,
        'error_msg', v_ErrorMsg
    );

END //
DELIMITER ;

-- 114. L1(입고) Port에서 입고완료후 반출입기 공병Zone에 공병을 hole에 내려놓았을때. 빈병 입고완료 했을때 (#11 공정시작)
-- GPT prompt
-- 1.입력 파라메터는 json type. 내용은 아래와 같음.
--       {
--          "FmNode" : "InOutBottle",
--          "ToNode" : "DB_Manager",
--          "BottleID" : "ID_001",
--          "Position" : "2111"
--          "EqpGroupID" : 1               // 생략가능, 반출입기
--          "EqpSeqNo" : 1,                // 생략가능
--          "PortEvent" : "UnloadComp"
--       }
-- Return  json type. 내용은 아래와 같음.
--       {
--          "status_code" : 200,
--          "sender_controller" : "Dispatcher" and "DB_Manager"    // 입력파라메터의 ToNode값
--          "error_msg" : "None"
--       }
-- table schema는 아래와 같음.
-- CREATE TABLE tBottleInfoOfHoleAtInOutBottle (
--    EqpSeqNo                 CHAR(1) NOT NULL,       -- 호기 (1부터 시작)
--    ZoneName                 CHAR(7),                -- 좌:Empty, 우:Filled
--    Position                 CHAR(4) NOT NULL,       -- Stocker에서 위치정보
--    UsageFlag                CHAR(1) default 'O',    -- 'O':사용가능, 'X':사용불가
--    AllocationPriority       TINYINT default 1,      -- 1 부터 시작
--    EventTime                DATETIME,               -- Event Time
--    BottleID                 CHAR(15)                -- Bottle ID
-- ) ON [Process];
-- 송신메세지에 EqpGroupID 있으면 EqpGroupID의 Value 읽고, 없으면 FmNode의 Value을 
-- 이용하여 함수 fGetEqpGroupID_FmParameterValue 이용하여 읽는다.
-- 입력 파라메터에 "EqpSeqNo" 정의되어 있지 않으면 '1' 세팅하고 있으면 그 값을 읽어줘.
-- tMstEqp table의 field LoadPort_1 값을 PortEvent 값으로 수정한다.
-- position 정보를 읽고 그 값을 tBottleInfoOfHoleAtInOutBottle update 하는 함수를 만들어서 처리해줘. 
-- 이때 ZoneName는 'Empty', EventTime은 현재시간 수정해줘.
-- maria db를 사용하고 있고, 예외 처리를 위한 DECLARE ... HANDLER 구문추가해줘.
--
-- 2 CREATE TABLE tProcBottle (
--    BottleID                 CHAR(15) NOT NULL,      -- Bottle ID
--    -- 현공정에 대한 정의
--    CurrEqpGroupID           CHAR(1) NOT NULL,       -- 현재 설비군 ID
--    CurrEqpSeqNo             CHAR(1) NOT NULL,       -- 호기 (1부터 시작)
--    CurrOperID               CHAR(1) NOT NULL,       -- 현재 작업 ID
--    -- 다음공정에 대한 정의
--    NextEqpGroupID           CHAR(1) NOT NULL,       -- 차기 설비군 ID
--    NextOperID               CHAR(1) NOT NULL,       -- 현재 작업 ID
--    --
--    StartTime                DATETIME,               -- 착공시간
-- ''''
-- )
-- CurrEqpGroupID값은 EqpGroupID  대입하고, CurrEqpSeqNo값은 EqpSeqNo 대입해서 CurrOperID='1' 
-- tProcBottle table을 update 추가해줘
--
-- 3.    -- tMstRouteOper 테이블에서 NextEqpGroupID와 NextOperID를 가져옴
--    SELECT NextEqpGroupID, NextOperID
--    INTO v_NextEqpGroupID, v_NextOperID
--    FROM tMstRouteOper
--    WHERE CurrEqpGroupID = p_CurrEqpGroupID
--      AND CurrOperID = p_CurrOperID
--    LIMIT 1;
-- NextEqpGroupID, NextOperID 읽고 tProcBottle table에 NextEqpGroupID, NextOperID 같이 update 해줘
-- 4. 업데이트하는 함수를 만들고, 해당 함수를 호출하도록 프로시저를 수정하려면 다음과 같이 할 수 있습니다:
DELIMITER //
CREATE PROCEDURE spEmptyBottleUnloadCompAtWorkingArea(IN jsonInput JSON, OUT jsonOutput JSON)
BEGIN
    DECLARE v_EqpGroupID CHAR(1);
    DECLARE v_EqpSeqNo CHAR(1) DEFAULT '1';
    DECLARE v_FmNode VARCHAR(50);
    DECLARE v_ToNode VARCHAR(255);
    DECLARE v_BottleID CHAR(15);
    DECLARE v_Position CHAR(4);
    DECLARE v_PortEvent VARCHAR(50);
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_ErrorMsg VARCHAR(255) DEFAULT 'None';
    DECLARE v_ErrorText VARCHAR(255);
    DECLARE v_ErrorCode INT;
    DECLARE v_NextEqpGroupID CHAR(1);
    DECLARE v_NextOperID CHAR(1);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_ErrorText = MESSAGE_TEXT;
        GET DIAGNOSTICS CONDITION 1 v_ErrorCode = MYSQL_ERRNO;

        SET v_StatusCode = 500;
        SET v_ErrorMsg = 'Database error';

        -- Insert error details into tProcSqlError table
        INSERT INTO tProcSqlError (ProcedureName, ErrorCode, ErrorMessage) 
        VALUES ('spEmptyBottleUnloadCompAtWorkingArea', v_ErrorCode, v_ErrorText);

        SET jsonOutput = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_ToNode,
            'error_msg', v_ErrorMsg
        );
        ROLLBACK;
    END;

    -- Extract values from JSON input
    SET v_FmNode = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.FmNode'));
    SET v_ToNode = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.ToNode'));
    SET v_BottleID = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.BottleID'));
    SET v_Position = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.Position'));
    SET v_PortEvent = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.PortEvent'));

    -- Check if EqpGroupID is provided, if not use FmNode value with f_GetEqpGroupID_FmParameterValue function
    IF JSON_CONTAINS_PATH(jsonInput, 'one', '$.EqpGroupID') THEN
        SET v_EqpGroupID = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.EqpGroupID'));
    ELSE
        SET v_EqpGroupID = f_GetEqpGroupID_FmParameterValue(v_FmNode);
    END IF;

    -- Check if EqpSeqNo is provided, if not set to default 1
    IF JSON_CONTAINS_PATH(jsonInput, 'one', '$.EqpSeqNo') THEN
        SET v_EqpSeqNo = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.EqpSeqNo'));
    END IF;

    -- Update the tMstEqp table
    CALL sp_UpdatePortEvent_MstEqp(v_EqpGroupID, v_EqpSeqNo, v_PortEvent, 'LoadPort_1');

    -- Update the tBottleInfoOfHoleAtInOutBottle table
    CALL sp_UpdatePosition_BottleInfoOfHoleAtInOutBottle(v_BottleID);

    -- Get NextEqpGroupID and NextOperID from tMstRouteOper table
    CALL sp_GetNextEqpGroupIDAndOperID_MstRouteOper(v_EqpGroupID, '1', v_NextEqpGroupID, v_NextOperID);

    -- Update the tProcBottle table
    CALL sp_Update_ProcBottle(v_BottleID, v_EqpGroupID, v_EqpSeqNo);

    -- Set the JSON output
    SET jsonOutput = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_ToNode,
        'error_msg', v_ErrorMsg
    );

END //
DELIMITER ;

-- 115. FilledBottleLoadReqAtWorkingArea(U1 Port)      반출입기 U1(출하) Port에서 실병 입고요청(LoadReq)메세지
-- 116. FilledBottleLoadCompAtWorkingArea(U1 Port)     반출입기 U1(출하) Port에서 실병 도착완료(LoadComp)메세지
-- 117. FilledBottleUnloadReqAtWorkingArea(U1 Port)    반출입기 U1(출하) Port에서 실병 출하요청(UnloadReq)메세지
--
DELIMITER //
CREATE PROCEDURE spEmptyBottlePortEventAtWorkingArea(IN jsonInput JSON, OUT jsonOutput JSON)
BEGIN
    DECLARE v_EqpSeqNo INT DEFAULT 1;
    DECLARE v_EqpGroupID CHAR(1);
    DECLARE v_FmNode VARCHAR(50);
    DECLARE v_ToNode VARCHAR(255);
    DECLARE v_PortEvent VARCHAR(50);
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_ErrorMsg VARCHAR(255) DEFAULT 'None';
    DECLARE v_ErrorText VARCHAR(255);
    DECLARE v_ErrorCode INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_ErrorText = MESSAGE_TEXT;
        GET DIAGNOSTICS CONDITION 1 v_ErrorCode = MYSQL_ERRNO;

        SET v_StatusCode = 500;
        SET v_ErrorMsg = 'Database error';

        -- Insert error details into tProcSqlError table
        INSERT INTO tProcSqlError (ProcedureName, ErrorCode, ErrorMessage) 
        VALUES ('spEmptyBottlePortEventAtWorkingArea', v_ErrorCode, v_ErrorText);

        SET jsonOutput = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_ToNode,
            'error_msg', v_ErrorMsg
        );
        ROLLBACK;
    END;

    -- Extract values from JSON input
    SET v_FmNode = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.FmNode'));
    SET v_ToNode = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.ToNode'));
    SET v_PortEvent = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.PortEvent'));

    -- Check if EqpGroupID is provided, if not use FmNode value with fGetEqpGroupID_FmParameterValue function
    IF JSON_CONTAINS_PATH(jsonInput, 'one', '$.EqpGroupID') THEN
        SET v_EqpGroupID = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.EqpGroupID'));
    ELSE
        SET v_EqpGroupID = fGetEqpGroupID_FmParameterValue(v_FmNode);
    END IF;

    -- Check if EqpSeqNo is provided, if not set to default 1
    IF JSON_CONTAINS_PATH(jsonInput, 'one', '$.EqpSeqNo') THEN
        SET v_EqpSeqNo = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.EqpSeqNo'));
    END IF;

    -- Update the tMstEqp table
    UPDATE tMstEqp
    SET UnloadPort_1 = v_PortEvent
    WHERE EqpGroupID = v_EqpGroupID AND EqpSeqNo = v_EqpSeqNo;

    -- Set the JSON output
    SET jsonOutput = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_ToNode,
        'EqpGroupID', v_EqpGroupID,
        'EqpSeqNo', v_EqpSeqNo,
        'error_msg', v_ErrorMsg
    );

END //
DELIMITER ;

-- 118. FilledBottleUnloadCompAtWorkingArea(U1 Port)   반출입기 U1(출하) Port에서 실병 출하완료(UnloadComp)메세지(#13 공정
--       {
--          "FmNode" : "InOutBottle",
--          "ToNode" : "Dispatcher" and "DB_Manager",
--          "EqpGroupID" : 1               // FmNode 추정가능. 생략가능
--          "EqpSeqNo" : 1,                // 정의하지 않으면 1로 추정함. 생략가능
--          "PortEvent" : "UnloadComp"
--          "BottleID" : "ID_001"
--       }
--
DELIMITER //
CREATE PROCEDURE spFilledBottleUnloadCompAtWorkingArea(IN jsonInput JSON, OUT jsonOutput JSON)
BEGIN
    DECLARE v_EqpGroupID CHAR(1);
    DECLARE v_EqpSeqNo CHAR(1) DEFAULT '1';
    DECLARE v_FmNode VARCHAR(50);
    DECLARE v_ToNode VARCHAR(255);
    DECLARE v_BottleID CHAR(15);
    DECLARE v_Position CHAR(4);
    DECLARE v_PortEvent VARCHAR(50);
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_ErrorMsg VARCHAR(255) DEFAULT 'None';
    DECLARE v_ErrorText VARCHAR(255);
    DECLARE v_ErrorCode INT;
    DECLARE v_NextEqpGroupID CHAR(1);
    DECLARE v_NextOperID CHAR(1);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_ErrorText = MESSAGE_TEXT;
        GET DIAGNOSTICS CONDITION 1 v_ErrorCode = MYSQL_ERRNO;

        SET v_StatusCode = 500;
        SET v_ErrorMsg = 'Database error';

        -- Insert error details into tProcSqlError table
        INSERT INTO tProcSqlError (ProcedureName, ErrorCode, ErrorMessage) 
        VALUES ('spEmptyBottleUnloadCompAtWorkingArea', v_ErrorCode, v_ErrorText);

        SET jsonOutput = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_ToNode,
            'error_msg', v_ErrorMsg
        );
        ROLLBACK;
    END;

    -- Extract values from JSON input
    SET v_FmNode = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.FmNode'));
    SET v_ToNode = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.ToNode'));
    SET v_BottleID = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.BottleID'));
    SET v_Position = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.Position'));
    SET v_PortEvent = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.PortEvent'));

    -- Check if EqpGroupID is provided, if not use FmNode value with fGetEqpGroupID_FmParameterValue function
    IF JSON_CONTAINS_PATH(jsonInput, 'one', '$.EqpGroupID') THEN
        SET v_EqpGroupID = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.EqpGroupID'));
    ELSE
        SET v_EqpGroupID = fGetEqpGroupID_FmParameterValue(v_FmNode);
    END IF;

    -- Check if EqpSeqNo is provided, if not set to default 1
    IF JSON_CONTAINS_PATH(jsonInput, 'one', '$.EqpSeqNo') THEN
        SET v_EqpSeqNo = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.EqpSeqNo'));
    END IF;

    -- Call the function to update the tMstEqp table
    CALL UpdateMstEqp(v_EqpGroupID, v_EqpSeqNo, v_PortEvent);

    -- Call the function to update the tBottleInfoOfHoleAtInOutBottle table
    CALL UpdateBottleInfoOfHoleAtInOutBottle(v_BottleID);

    -- Call the function to update the tProcBottle table
    CALL UpdateProcBottle(v_BottleID, v_EqpGroupID, v_EqpSeqNo);

    -- Set the JSON output
    SET jsonOutput = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_ToNode,
        'error_msg', v_ErrorMsg
    );

END //
DELIMITER ;

-- 121. 반출입기 L2(입고) Port에서 실병 입고요청(LoadReq)메세지
-- 122. L2(입고) Port에서 반출입기 실병 도착완료(LoadComp)메세지(#13 공정시작)
-- 123. U2(출하) Port에서 반출입기 빈병 입고요청(LoadReq)메세지
-- GPT prompt
-- 1. 입력 파라메터는 json type. 내용은 아래와 같음.
--       {
--          "EqpGroupID" : 1               // 설비군
--          "EqpSeqNo" : 1,                // 정의하지 않으면 1로 추정함. 생략가능
--          "PortName" : "L2",
--          "PortEvent" : "UnloadComp"             
--       }
-- 입력 파라메터에서 PortName이 정의되어 있지 않으면 "ProcessStatus"
-- "PortName" : "L1" 이면  "LoadPort_1"
-- "PortName" : "U1" 이면 "UnloadPort_1"
-- "PortName" : "L2" 이면 "LoadPort_2"
-- "PortName" : "U2" 이면 "UnloadPort_2"  
-- return 하는 함수를 만들고 
-- 관련 DB Table
-- CREATE TABLE tMstEqp (
--        EqpGroupID               CHAR(1) NOT NULL,       -- 설비군ID
--        EqpSeqNo                 TINYINT NOT NULL,       -- 호기 (1부터 시작)
--        ...
--        EqpStatus                NVARCHAR(10),           -- 장비상태 (PowerOn, PowerOff, Reserve, Ready, Run, Idle, Pause, Trouble:통신불가, Maintenance, Waiting)
--    ProcessStatus            NVARCHAR(12),           -- 진행 상태(LoadReq, LoadComp, UnLoadReq, UnLoadComp, Reserve), 반출입기 이외 장
--    LoadPort_1               NVARCHAR(12),           -- 진행 상태(LoadReq, LoadComp, UnLoadReq, UnLoadComp, Reserve)
--    LoadPort_2               NVARCHAR(12),           -- 진행 상태(LoadReq, LoadComp, UnLoadReq, UnLoadComp, Reserve)
--    UnloadPort_1             NVARCHAR(12),           -- 진행 상태(LoadReq, LoadComp, UnLoadReq, UnLoadComp, Reserve)
--    UnloadPort_2             NVARCHAR(12),           -- 진행 상태(LoadReq, LoadComp, UnLoadReq, UnLoadComp, Reserve    }
-- PortName 에서 가져온 DB field 명에 PortEvent 값을 update 하는 stored procedure 만들어줘.
--  maria db를 사용하고 있고, 예외 처리를 위한 DECLARE ... HANDLER 구문추가해줘.
-- Error  발생하면 관련내용을 insert해줘.
-- 2. 입력값에 BottleID, Position 정보가 있으면 데이터 값을 읽고 sp_UpdatePosition_BottleInfoOfHoleAtInOutBottle 호출해줘.
DELIMITER //
CREATE PROCEDURE spUpdatePortEventAtInOutBottle(IN jsonInput JSON, OUT jsonOutput JSON)
BEGIN
    DECLARE v_EqpGroupID CHAR(1);
    DECLARE v_EqpSeqNo INT DEFAULT 1;
    DECLARE v_PortName VARCHAR(12) DEFAULT 'ProcessStatus';
    DECLARE v_PortEvent VARCHAR(50);
    DECLARE v_BottleID CHAR(15);
    DECLARE v_Position VARCHAR(50);
    DECLARE v_ZoneName VARCHAR(50);
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_ErrorMsg VARCHAR(255) DEFAULT 'None';
    DECLARE v_ErrorText VARCHAR(255);
    DECLARE v_ErrorCode INT;
    DECLARE v_FieldName VARCHAR(20);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_ErrorText = MESSAGE_TEXT;
        GET DIAGNOSTICS CONDITION 1 v_ErrorCode = MYSQL_ERRNO;

        SET v_StatusCode = 500;
        SET v_ErrorMsg = 'Database error';

        -- Insert error details into tProcSqlError table
        INSERT INTO tProcSqlError (ProcedureName, ErrorCode, ErrorMessage) 
        VALUES ('spUpdatePortEventAtWorkingArea', v_ErrorCode, v_ErrorText);

        SET jsonOutput = JSON_OBJECT(
            'status_code', v_StatusCode,
            'error_msg', v_ErrorMsg
        );
        ROLLBACK;
    END;

    -- Extract values from JSON input
    SET v_EqpGroupID = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.EqpGroupID'));
    SET v_PortEvent = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.PortEvent'));
    SET v_BottleID = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.BottleID'));
    SET v_Position = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.Position'));
    SET v_ZoneName = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.ZoneName'));

    -- Check if EqpSeqNo is provided, if not set to default 1
    IF JSON_CONTAINS_PATH(jsonInput, 'one', '$.EqpSeqNo') THEN
        SET v_EqpSeqNo = CAST(JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.EqpSeqNo')) AS UNSIGNED);
    END IF;

    -- Check if PortName is provided, if not set to 'ProcessStatus'
    IF JSON_CONTAINS_PATH(jsonInput, 'one', '$.PortName') THEN
        SET v_PortName = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.PortName'));
    END IF;

    -- Determine the field name based on the PortName value
    CASE v_PortName
        WHEN 'L1' THEN SET v_FieldName = 'LoadPort_1';
        WHEN 'U1' THEN SET v_FieldName = 'UnloadPort_1';
        WHEN 'L2' THEN SET v_FieldName = 'LoadPort_2';
        WHEN 'U2' THEN SET v_FieldName = 'UnloadPort_2';
        ELSE SET v_FieldName = 'ProcessStatus';
    END CASE;

    -- Update the corresponding field in the tMstEqp table using sp_UpdatePortEvent_MstEqp
    CALL sp_UpdatePortEvent_MstEqp(v_EqpGroupID, v_EqpSeqNo, v_PortEvent, v_FieldName);

    -- Call sp_UpdatePosition_BottleInfoOfHoleAtInOutBottle if BottleID, Position, and ZoneName are provided
    IF v_BottleID IS NOT NULL AND v_Position IS NOT NULL AND v_ZoneName IS NOT NULL THEN
        CALL sp_UpdatePosition_BottleInfoOfHoleAtInOutBottle(v_BottleID, v_Position, v_ZoneName);
    END IF;

    -- Set the JSON output
    SET jsonOutput = JSON_OBJECT(
        'status_code', v_StatusCode,
        'EqpGroupID', v_EqpGroupID,
        'EqpSeqNo', v_EqpSeqNo,
        'PortName', v_PortName,
        'PortEvent', v_PortEvent,
        'BottleID', v_BottleID,
        'Position', v_Position,
        'ZoneName', v_ZoneName,
        'error_msg', v_ErrorMsg
    );

END //
DELIMITER ;

-- 124. U2(출하) Port에서 반출입기 빈병 도착완료(LoadComp)메세지 (#11 공정완료)
-- GPT prompt
-- 1. spFilledBottleUnloadCompAtWorkingArea procedure에서
-- Position 파라메터가 입력되지 않았으면 default 값을 null로 처리해줘.
-- ZoneName 파라메터 추가해줘.
DELIMITER //
CREATE PROCEDURE spFilledBottleUnloadCompAtWorkingArea(IN jsonInput JSON, OUT jsonOutput JSON)
BEGIN
    DECLARE v_EqpGroupID CHAR(1);
    DECLARE v_EqpSeqNo CHAR(1) DEFAULT '1';
    DECLARE v_BottleID CHAR(15);
    DECLARE v_Position CHAR(4) DEFAULT NULL;
    DECLARE v_ZoneName VARCHAR(50);
    DECLARE v_PortEvent VARCHAR(50);
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_ErrorMsg VARCHAR(255) DEFAULT 'None';
    DECLARE v_ErrorText VARCHAR(255);
    DECLARE v_ErrorCode INT;
    DECLARE v_NextEqpGroupID CHAR(1);
    DECLARE v_NextOperID CHAR(1);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_ErrorText = MESSAGE_TEXT;
        GET DIAGNOSTICS CONDITION 1 v_ErrorCode = MYSQL_ERRNO;

        SET v_StatusCode = 500;
        SET v_ErrorMsg = 'Database error';

        -- Insert error details into tProcSqlError table
        INSERT INTO tProcSqlError (ProcedureName, ErrorCode, ErrorMessage) 
        VALUES ('spFilledBottleUnloadCompAtWorkingArea', v_ErrorCode, v_ErrorText);

        SET jsonOutput = JSON_OBJECT(
            'status_code', v_StatusCode,
            'error_msg', v_ErrorMsg
        );
        ROLLBACK;
    END;

    -- Extract values from JSON input
    SET v_EqpGroupID = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.EqpGroupID'));
    SET v_BottleID = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.BottleID'));
    SET v_Position = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.Position'));
    SET v_ZoneName = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.ZoneName'));
    SET v_PortEvent = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.PortEvent'));

    -- Check if EqpSeqNo is provided, if not set to default 1
    IF JSON_CONTAINS_PATH(jsonInput, 'one', '$.EqpSeqNo') THEN
        SET v_EqpSeqNo = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.EqpSeqNo'));
    END IF;

    -- Check if Position is provided, if not set to NULL
    IF NOT JSON_CONTAINS_PATH(jsonInput, 'one', '$.Position') THEN
        SET v_Position = NULL;
    END IF;

    -- Call the function to update the tMstEqp table
    CALL sp_UpdatePortEvent_MstEqp(v_EqpGroupID, v_EqpSeqNo, v_PortEvent, 'ProcessStatus');

    -- Call the function to update the tBottleInfoOfHoleAtInOutBottle table
    CALL sp_UpdatePosition_BottleInfoOfHoleAtInOutBottle(v_BottleID, v_Position, v_ZoneName);

    -- Call the function to update the tProcBottle table
    CALL sp_Update_ProcBottle(v_BottleID, v_EqpGroupID, v_EqpSeqNo);

    -- Set the JSON output
    SET jsonOutput = JSON_OBJECT(
        'status_code', v_StatusCode,
        'error_msg', v_ErrorMsg
    );

END //
DELIMITER ;

-- 131. 반출입기 hole capacity(Bottle 총 적재가능수량)
-- GPT prompt
-- 입력 파라메터는 json type. 내용은 아래와 같음.
--       {
--          "EqpGroupID" : 1               // 설비군
--          "EqpSeqNo" : 1,                // 정의하지 않으면 1로 추정함. 생략가능
--       }
-- 출력 파라메터는 json type. 내용은 아래와 같음.
--       {
--          "status_code" : 200,
--          "sender_controller" : "InOutBottle" or "DB_Manager"
--          "empty_bottle_zone_capacity" : 48,
--          "filled_bottle_zone_capacity" : 48,
--          "error_msg" : "None"
--       }
-- CREATE TABLE tMstEqp (
--    EqpGroupID               CHAR(1) NOT NULL,       -- 설비군ID
--    EqpSeqNo                 TINYINT NOT NULL,       -- 호기 (1부터 시작)
--    EqpName                  NVARCHAR(30),           -- 설비명
--    CapacityOfHole           TINYINT,                -- 분석기 설비 hole(병을 처리할수 있는) 케파
--    CapacityOfEmptyZone      TINYINT,                -- 반출입기 설비 hole(병을 처리할수 있는) 케파
--    CapacityOfFilledZone     TINYINT,                -- 반출입기 설비 hole(병을 처리할수 있는) 케파
--    CapacityOfLeftZone       TINYINT,                -- Stocker 설비 hole(병을 처리할수 있는) 케파
--    CapacityOfRightZone      TINYINT,                -- Stocker 설비 hole(병을 처리할수 있는) 케파
--   ....
-- tMstEqp table의 CapacityOfEmptyZone, CapacityOfFilledZone 값을 일고 출력 파라메터에 assign후 return 한다.
-- maria db를 사용하고 있고, 예외 처리를 위한 DECLARE ... HANDLER 구문추가해줘.
-- Error  발생하면 관련내용을 insert하는 stored procedure 만들어줘.
DELIMITER //
CREATE PROCEDURE spGetBottleCapacityAtInOutBottle(IN jsonInput JSON, OUT jsonOutput JSON)
BEGIN
    DECLARE v_EqpGroupID CHAR(1);
    DECLARE v_EqpSeqNo TINYINT DEFAULT 1;
    DECLARE v_CapacityOfEmptyZone TINYINT;
    DECLARE v_CapacityOfFilledZone TINYINT;
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_ErrorMsg VARCHAR(255) DEFAULT 'None';
    DECLARE v_ErrorText VARCHAR(255);
    DECLARE v_ErrorCode INT;
    DECLARE v_SenderController VARCHAR(50) DEFAULT 'DB_Manager';

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_ErrorText = MESSAGE_TEXT;
        GET DIAGNOSTICS CONDITION 1 v_ErrorCode = MYSQL_ERRNO;

        SET v_StatusCode = 500;
        SET v_ErrorMsg = 'Database error';

        -- Insert error details into tProcSqlError table
        INSERT INTO tProcSqlError (ProcedureName, ErrorCode, ErrorMessage) 
        VALUES ('spReadBottleZoneCapacity', v_ErrorCode, v_ErrorText);

        SET jsonOutput = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_SenderController,
            'empty_bottle_zone_capacity', NULL,
            'filled_bottle_zone_capacity', NULL,
            'error_msg', v_ErrorMsg
        );
        ROLLBACK;
    END;

    -- Extract values from JSON input
    SET v_EqpGroupID = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.EqpGroupID'));

    -- Check if EqpSeqNo is provided, if not set to default 1
    IF JSON_CONTAINS_PATH(jsonInput, 'one', '$.EqpSeqNo') THEN
        SET v_EqpSeqNo = CAST(JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.EqpSeqNo')) AS UNSIGNED);
    END IF;

    -- Read CapacityOfEmptyZone and CapacityOfFilledZone from tMstEqp table
    SELECT CapacityOfEmptyZone, CapacityOfFilledZone
    INTO v_CapacityOfEmptyZone, v_CapacityOfFilledZone
    FROM tMstEqp
    WHERE EqpGroupID = v_EqpGroupID AND EqpSeqNo = v_EqpSeqNo;

    -- Set the JSON output
    SET jsonOutput = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_SenderController,
        'empty_bottle_zone_capacity', v_CapacityOfEmptyZone,
        'filled_bottle_zone_capacity', v_CapacityOfFilledZone,
        'error_msg', v_ErrorMsg
    );

END //
DELIMITER ;

-- 132. RequestNumberOfSpareHole                       반출입기에 bottle 적재할 Empty hole 수량요청
-- GPT prompt
-- 입력 파라메터는 json type. 내용은 아래와 같음.
--       {
--          "EqpGroupID" : 1               // 설비군
--          "EqpSeqNo" : 1,                // 정의하지 않으면 1로 추정함. 생략가능
--       }
-- 출력 파라메터는 json type. 내용은 아래와 같음.
--       {
--          "status_code" : 200,
--          "sender_controller" : "InOutBottle" or "DB_Manager"
--          "num_of_empty_bottle_in_empty_bottle_zone" : 10,
--          "num_of_empty_bottle_in_filled_bottle_zone" : 15,
--          "error_msg" : "None"
--       }
-- CREATE TABLE tBottleInfoOfHoleAtInOutBottle (
--    EqpSeqNo                 CHAR(1) NOT NULL,       -- 호기 (1부터 시작)
--    ZoneName                 CHAR(7),                -- 좌:Empty, 우:Filled
--    Position                 CHAR(4) NOT NULL,       -- Stocker에서 위치정보
--    UsageFlag                CHAR(1) default 'O',    -- 'O':사용가능, 'X':사용불가
--    AllocationPriority       TINYINT default 1,      -- 1 부터 시작
--    EventTime                DATETIME,               -- Event Time
--    BottleID                 CHAR(15)                -- Bottle ID
-- ) ON [Process];
-- tBottleInfoOfHoleAtInOutBottle table의 ZoneName이 'Empty'일때 BottleID값이 null인 record 갯수를  num_of_empty_bottle_in_empty_bottle_zone assign한다.
-- ZoneName이 'Filled'일때 BottleID값이 null인 record 갯수를  num_of_empty_bottle_in_filled_bottle_zone assign한다.
-- maria db를 사용하고 있고, 예외 처리를 위한 DECLARE ... HANDLER 구문추가해줘.
-- Error  발생하면 관련내용을 insert하는 stored procedure 만들어줘.
DELIMITER //
CREATE PROCEDURE spReadBottleZoneInfo(IN jsonInput JSON, OUT jsonOutput JSON)
BEGIN
    DECLARE v_EqpGroupID CHAR(1);
    DECLARE v_EqpSeqNo CHAR(1) DEFAULT '1';
    DECLARE v_NumOfEmptyBottleInEmptyZone INT;
    DECLARE v_NumOfEmptyBottleInFilledZone INT;
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_ErrorMsg VARCHAR(255) DEFAULT 'None';
    DECLARE v_ErrorText VARCHAR(255);
    DECLARE v_ErrorCode INT;
    DECLARE v_SenderController VARCHAR(50) DEFAULT 'DB_Manager';

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_ErrorText = MESSAGE_TEXT;
        GET DIAGNOSTICS CONDITION 1 v_ErrorCode = MYSQL_ERRNO;

        SET v_StatusCode = 500;
        SET v_ErrorMsg = 'Database error';

        -- Insert error details into tProcSqlError table
        INSERT INTO tProcSqlError (ProcedureName, ErrorCode, ErrorMessage) 
        VALUES ('spReadBottleZoneInfo', v_ErrorCode, v_ErrorText);

        SET jsonOutput = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_SenderController,
            'num_of_empty_bottle_in_empty_bottle_zone', NULL,
            'num_of_empty_bottle_in_filled_bottle_zone', NULL,
            'error_msg', v_ErrorMsg
        );
        ROLLBACK;
    END;

    -- Extract values from JSON input
    SET v_EqpGroupID = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.EqpGroupID'));

    -- Check if EqpSeqNo is provided, if not set to default 1
    IF JSON_CONTAINS_PATH(jsonInput, 'one', '$.EqpSeqNo') THEN
        SET v_EqpSeqNo = CAST(JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.EqpSeqNo')) AS UNSIGNED);
    END IF;

    -- Count the number of empty bottles in empty bottle zone
    SELECT COUNT(*)
    INTO v_NumOfEmptyBottleInEmptyZone
    FROM tBottleInfoOfHoleAtInOutBottle
    WHERE ZoneName = 'Empty' AND EqpSeqNo = v_EqpSeqNo AND BottleID IS NULL;

    -- Count the number of empty bottles in filled bottle zone
    SELECT COUNT(*)
    INTO v_NumOfEmptyBottleInFilledZone
    FROM tBottleInfoOfHoleAtInOutBottle
    WHERE ZoneName = 'Filled' AND EqpSeqNo = v_EqpSeqNo AND BottleID IS NULL;

    -- Set the JSON output
    SET jsonOutput = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_SenderController,
        'num_of_empty_bottle_in_empty_bottle_zone', v_NumOfEmptyBottleInEmptyZone,
        'num_of_empty_bottle_in_filled_bottle_zone', v_NumOfEmptyBottleInFilledZone,
        'error_msg', v_ErrorMsg
    );

END //
DELIMITER ;

-- 133. RequestInfoOfSpareHoles                        반출입기에 bottle투입하기 위한 Empty hole 정보요청
-- GPT prompt
-- 입력 파라메터는 json type. 내용은 아래와 같음.
--       {
--          "EqpGroupID" : 1               // 설비군
--          "EqpSeqNo" : 1,                // 정의하지 않으면 1로 추정함. 생략가능
--       }
-- 출력 파라메터는 json type. 내용은 아래와 같음.
--       {
--          "status_code" : 200,
--          "sender_controller" : "InOutBottle" or "DB_Manager"
--          "position_in_empty_bottle_zone" : "1111, 1114, 1115",
--          "position_in_filled_bottle_zone" : "2111, 2114, 2115",
--          "error_msg" : "None"
--       }	  
-- CREATE TABLE tBottleInfoOfHoleAtInOutBottle (
--    EqpSeqNo                 CHAR(1) NOT NULL,       -- 호기 (1부터 시작)
--    ZoneName                 CHAR(7),                -- 좌:Empty, 우:Filled
--    Position                 CHAR(4) NOT NULL,       -- Stocker에서 위치정보
--    UsageFlag                CHAR(1) default 'O',    -- 'O':사용가능, 'X':사용불가
--    AllocationPriority       TINYINT default 1,      -- 1 부터 시작
--    EventTime                DATETIME,               -- Event Time
--    BottleID                 CHAR(15)                -- Bottle ID
-- ) ON [Process];
-- tBottleInfoOfHoleAtInOutBottle table의 
-- ZoneName이 'Empty'일때 BottleID값이 null인 Position 정보를  position_in_empty_bottle_zone assign한다.
-- ZoneName이 'Filled'일때 BottleID값이 null인 Position 정보를  position_in_filled_bottle_zone assign한다.
-- maria db를 사용하고 있고, 예외 처리를 위한 DECLARE ... HANDLER 구문추가해줘.
-- Error  발생하면 관련내용을 insert하는 stored procedure 만들어줘.
DELIMITER //
CREATE PROCEDURE spReadBottleZonePositions(IN jsonInput JSON, OUT jsonOutput JSON)
BEGIN
    DECLARE v_EqpGroupID CHAR(1);
    DECLARE v_EqpSeqNo CHAR(1) DEFAULT '1';
    DECLARE v_PositionsInEmptyZone TEXT;
    DECLARE v_PositionsInFilledZone TEXT;
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_ErrorMsg VARCHAR(255) DEFAULT 'None';
    DECLARE v_ErrorText VARCHAR(255);
    DECLARE v_ErrorCode INT;
    DECLARE v_SenderController VARCHAR(50) DEFAULT 'DB_Manager';

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_ErrorText = MESSAGE_TEXT;
        GET DIAGNOSTICS CONDITION 1 v_ErrorCode = MYSQL_ERRNO;

        SET v_StatusCode = 500;
        SET v_ErrorMsg = 'Database error';

        -- Insert error details into tProcSqlError table
        INSERT INTO tProcSqlError (ProcedureName, ErrorCode, ErrorMessage) 
        VALUES ('spReadBottleZonePositions', v_ErrorCode, v_ErrorText);

        SET jsonOutput = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_SenderController,
            'position_in_empty_bottle_zone', NULL,
            'position_in_filled_bottle_zone', NULL,
            'error_msg', v_ErrorMsg
        );
        ROLLBACK;
    END;

    -- Extract values from JSON input
    SET v_EqpGroupID = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.EqpGroupID'));

    -- Check if EqpSeqNo is provided, if not set to default 1
    IF JSON_CONTAINS_PATH(jsonInput, 'one', '$.EqpSeqNo') THEN
        SET v_EqpSeqNo = CAST(JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.EqpSeqNo')) AS UNSIGNED);
    END IF;

    -- Get positions of empty bottles in empty bottle zone
    SELECT GROUP_CONCAT(Position)
    INTO v_PositionsInEmptyZone
    FROM tBottleInfoOfHoleAtInOutBottle
    WHERE ZoneName = 'Empty' AND EqpSeqNo = v_EqpSeqNo AND BottleID IS NULL;

    -- Get positions of empty bottles in filled bottle zone
    SELECT GROUP_CONCAT(Position)
    INTO v_PositionsInFilledZone
    FROM tBottleInfoOfHoleAtInOutBottle
    WHERE ZoneName = 'Filled' AND EqpSeqNo = v_EqpSeqNo AND BottleID IS NULL;

    -- Set the JSON output
    SET jsonOutput = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_SenderController,
        'position_in_empty_bottle_zone', v_PositionsInEmptyZone,
        'position_in_filled_bottle_zone', v_PositionsInFilledZone,
        'error_msg', v_ErrorMsg
    );

END //
DELIMITER ;

-- 134. RequestBottleInfoByHole                        반출입기 Hole 존재하는 bottle정보요청
-- GPT prompt
-- 입력 파라메터는 json type. 내용은 아래와 같음.
--       {
--          "EqpGroupID" : 1               // 설비군
--          "EqpSeqNo" : 1,                // 정의하지 않으면 1로 추정함. 생략가능
--       }
-- 출력 파라메터는 json type. 내용은 아래와 같음.
--       {
--          "status_code" : 200,
--          "sender_controller" : "InOutBottle" or "DB_Manager"
--          "empty_bottle_zone" : [
--             {"1011" : "bot_0136"},
--                 ...
--             {"1035" : "bot_0136"}
--          ],
--          "filled_bottle_zone" : [
--             {"2011" : "bot_2136"},
--                 ...
--             {"2035" : "bot_2136"}
--          ],
--          "error_msg" : "None"
--       }	  
-- CREATE TABLE tBottleInfoOfHoleAtInOutBottle (
--    EqpSeqNo                 CHAR(1) NOT NULL,       -- 호기 (1부터 시작)
--    ZoneName                 CHAR(7),                -- 좌:Empty, 우:Filled
--    Position                 CHAR(4) NOT NULL,       -- Stocker에서 위치정보
--    UsageFlag                CHAR(1) default 'O',    -- 'O':사용가능, 'X':사용불가
--    AllocationPriority       TINYINT default 1,      -- 1 부터 시작
--    EventTime                DATETIME,               -- Event Time
--    BottleID                 CHAR(15)                -- Bottle ID
-- ) ON [Process];
-- tBottleInfoOfHoleAtInOutBottle table의 
-- ZoneName이 'Empty'일때 BottleID값이 null아닌 record의 Position 정보와 BottleID를  empty_bottle_zone assign한다.
-- ZoneName이 'Filled'일때 BottleID값이 null아닌 record의 Position 정보와 BottleID를  filled_bottle_zone assign한다.
-- maria db를 사용하고 있고, 예외 처리를 위한 DECLARE ... HANDLER 구문추가해줘.
-- Error  발생하면 관련내용을 insert하는 stored procedure 만들어줘.
DELIMITER //
CREATE PROCEDURE spReadBottleZoneDetails(IN jsonInput JSON, OUT jsonOutput JSON)
BEGIN
    DECLARE v_EqpGroupID CHAR(1);
    DECLARE v_EqpSeqNo CHAR(1) DEFAULT '1';
    DECLARE v_EmptyBottleZone JSON;
    DECLARE v_FilledBottleZone JSON;
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_ErrorMsg VARCHAR(255) DEFAULT 'None';
    DECLARE v_ErrorText VARCHAR(255);
    DECLARE v_ErrorCode INT;
    DECLARE v_SenderController VARCHAR(50) DEFAULT 'DB_Manager';

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_ErrorText = MESSAGE_TEXT;
        GET DIAGNOSTICS CONDITION 1 v_ErrorCode = MYSQL_ERRNO;

        SET v_StatusCode = 500;
        SET v_ErrorMsg = 'Database error';

        -- Insert error details into tProcSqlError table
        INSERT INTO tProcSqlError (ProcedureName, ErrorCode, ErrorMessage) 
        VALUES ('spReadBottleZoneDetails', v_ErrorCode, v_ErrorText);

        SET jsonOutput = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_SenderController,
            'empty_bottle_zone', NULL,
            'filled_bottle_zone', NULL,
            'error_msg', v_ErrorMsg
        );
        ROLLBACK;
    END;

    -- Extract values from JSON input
    SET v_EqpGroupID = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.EqpGroupID'));

    -- Check if EqpSeqNo is provided, if not set to default 1
    IF JSON_CONTAINS_PATH(jsonInput, 'one', '$.EqpSeqNo') THEN
        SET v_EqpSeqNo = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.EqpSeqNo'));
    END IF;

    -- Get positions and BottleIDs of empty bottles in empty bottle zone
    SET v_EmptyBottleZone = (
        SELECT JSON_ARRAYAGG(JSON_OBJECT(Position, BottleID))
        FROM tBottleInfoOfHoleAtInOutBottle
        WHERE ZoneName = 'Empty' AND BottleID IS NOT NULL AND EqpSeqNo = v_EqpSeqNo
    );

    -- Get positions and BottleIDs of empty bottles in filled bottle zone
    SET v_FilledBottleZone = (
        SELECT JSON_ARRAYAGG(JSON_OBJECT(Position, BottleID))
        FROM tBottleInfoOfHoleAtInOutBottle
        WHERE ZoneName = 'Filled' AND BottleID IS NOT NULL AND EqpSeqNo = v_EqpSeqNo
    );

    -- Set the JSON output
    SET jsonOutput = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_SenderController,
        'empty_bottle_zone', v_EmptyBottleZone,
        'filled_bottle_zone', v_FilledBottleZone,
        'error_msg', v_ErrorMsg
    );

END //
DELIMITER ;

-- 141. CompareEqpBottleInfo2DB_BottleInfo             반출입기에 있는 재공재고정보와 DB에 있는 정보를 비교한다
-- GPT prompt
-- 입력 파라메터는 json type. 내용은 아래와 같음.
--       {
--          "EqpGroupID" : '1',            // 설비군 (InOutBottle)
--          "EqpSeqNo" : 1,                // 정의하지 않으면 1로 추정함. 생략가능
--          "empty_bottle_zone" : [
--             {"1011" : "bot_0136"},
--                 ...
--             {"1035" : "bot_0136"}
--          ],
--          "filled_bottle_zone" : [
--             {"2011" : "bot_2136"},
--                 ...
--             {"2035" : "bot_2136"}
--          ],
--       }
-- 출력 파라메터는 json type. 내용은 아래와 같음.
--       {
--          "status_code" : 200,
--          "sender_controller" : "DB_Manager",    //
--          "TotCountOfBottles" : 70,
--          "NormalCountOfBottles" : 68,
--          "AbnormalCountOfBottles" : 2,
--          "BottleInfo" : [
--             {
--                 "BottleID" : "ID_001",
--                 "PositionOfInputParameter" : "1021",
--                 "PositionOfDB" : "2021"
--             },
--             {
--                 "BottleID" : "ID_002",
--                 "PositionOfInputParameter" : "1022",
--                 "PositionOfDB" : null
--             },
--          ],
--          "error_msg" : "None"
--       }	  
-- CREATE TABLE tBottleInfoOfHoleAtInOutBottle (
--    EqpSeqNo                 CHAR(1) NOT NULL,       -- 호기 (1부터 시작)
--    ZoneName                 CHAR(7),                -- 좌:Empty, 우:Filled
--    Position                 CHAR(4) NOT NULL,       -- Stocker에서 위치정보
--    UsageFlag                CHAR(1) default 'O',    -- 'O':사용가능, 'X':사용불가
--    AllocationPriority       TINYINT default 1,      -- 1 부터 시작
--    EventTime                DATETIME,               -- Event Time
--    BottleID                 CHAR(15)                -- Bottle ID
-- ) ON [Process];
-- tBottleInfoOfHoleAtInOutBottle table의 
-- 입력파라메터에서 입력된 Postion과 Bottle정보와 DB에 정보를 비교해서 출력파라메터를 완성해줘
-- maria db를 사용하고 있고, 예외 처리를 위한 DECLARE ... HANDLER 구문추가해줘.
-- Error  발생하면 관련내용을 insert하는 stored procedure 만들어줘.
DELIMITER //
CREATE PROCEDURE spCompareBottleInfo(IN jsonInput JSON, OUT jsonOutput JSON)
BEGIN
    DECLARE v_EqpGroupID CHAR(1);
    DECLARE v_EqpSeqNo CHAR(1) DEFAULT '1';
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_ErrorMsg VARCHAR(255) DEFAULT 'None';
    DECLARE v_ErrorText VARCHAR(255);
    DECLARE v_ErrorCode INT;
    DECLARE v_SenderController VARCHAR(50) DEFAULT 'DB_Manager';
    DECLARE v_TotCountOfBottles INT DEFAULT 0;
    DECLARE v_NormalCountOfBottles INT DEFAULT 0;
    DECLARE v_AbnormalCountOfBottles INT DEFAULT 0;
    DECLARE v_BottleInfo JSON;
    DECLARE v_JsonRow JSON;
    DECLARE v_Position VARCHAR(4);
    DECLARE v_BottleID CHAR(15);
    DECLARE v_DBPosition VARCHAR(4);
    DECLARE v_DB_BottleID CHAR(15);
    DECLARE v_CurrentIndex INT DEFAULT 0;
    DECLARE v_TotalItems INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_ErrorText = MESSAGE_TEXT;
        GET DIAGNOSTICS CONDITION 1 v_ErrorCode = MYSQL_ERRNO;

        SET v_StatusCode = 500;
        SET v_ErrorMsg = 'Database error';

        -- Insert error details into tProcSqlError table
        INSERT INTO tProcSqlError (ProcedureName, ErrorCode, ErrorMessage) 
        VALUES ('spCompareBottleInfo', v_ErrorCode, v_ErrorText);

        SET jsonOutput = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_SenderController,
            'TotCountOfBottles', NULL,
            'NormalCountOfBottles', NULL,
            'AbnormalCountOfBottles', NULL,
            'BottleInfo', NULL,
            'error_msg', v_ErrorMsg
        );
        ROLLBACK;
    END;

    -- Extract values from JSON input
    SET v_EqpGroupID = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.EqpGroupID'));

    -- Check if EqpSeqNo is provided, if not set to default 1
    IF JSON_CONTAINS_PATH(jsonInput, 'one', '$.EqpSeqNo') THEN
        SET v_EqpSeqNo = CAST(JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.EqpSeqNo')) AS UNSIGNED);
    END IF;

    -- Process empty_bottle_zone
    SET v_TotalItems = JSON_LENGTH(JSON_EXTRACT(jsonInput, '$.empty_bottle_zone'));
    WHILE v_CurrentIndex < v_TotalItems DO
        SET v_JsonRow = JSON_EXTRACT(jsonInput, CONCAT('$.empty_bottle_zone[', v_CurrentIndex, ']'));
        SET v_Position = JSON_UNQUOTE(JSON_KEYS(v_JsonRow));
        SET v_BottleID = JSON_UNQUOTE(JSON_EXTRACT(v_JsonRow, CONCAT('$."', v_Position, '"')));

        -- Query to find the BottleID in the database
        SELECT Position, BottleID
        INTO v_DBPosition, v_DB_BottleID
        FROM tBottleInfoOfHoleAtInOutBottle
        WHERE EqpSeqNo = v_EqpSeqNo AND ZoneName = 'Empty' AND Position = v_Position;

        IF v_DB_BottleID = v_BottleID THEN
            SET v_NormalCountOfBottles = v_NormalCountOfBottles + 1;
        ELSE
            SET v_AbnormalCountOfBottles = v_AbnormalCountOfBottles + 1;
        END IF;

        SET v_TotCountOfBottles = v_TotCountOfBottles + 1;

        SET v_BottleInfo = JSON_ARRAY_APPEND(
            v_BottleInfo, '$', 
            JSON_OBJECT(
                'BottleID', v_BottleID,
                'PositionOfInputParameter', v_Position,
                'PositionOfDB', v_DBPosition
            )
        );

        SET v_CurrentIndex = v_CurrentIndex + 1;
    END WHILE;

    -- Process filled_bottle_zone
    SET v_CurrentIndex = 0;
    SET v_TotalItems = JSON_LENGTH(JSON_EXTRACT(jsonInput, '$.filled_bottle_zone'));
    WHILE v_CurrentIndex < v_TotalItems DO
        SET v_JsonRow = JSON_EXTRACT(jsonInput, CONCAT('$.filled_bottle_zone[', v_CurrentIndex, ']'));
        SET v_Position = JSON_UNQUOTE(JSON_KEYS(v_JsonRow));
        SET v_BottleID = JSON_UNQUOTE(JSON_EXTRACT(v_JsonRow, CONCAT('$."', v_Position, '"')));

        -- Query to find the BottleID in the database
        SELECT Position, BottleID
        INTO v_DBPosition, v_DB_BottleID
        FROM tBottleInfoOfHoleAtInOutBottle
        WHERE EqpSeqNo = v_EqpSeqNo AND ZoneName = 'Filled' AND Position = v_Position;

        IF v_DB_BottleID = v_BottleID THEN
            SET v_NormalCountOfBottles = v_NormalCountOfBottles + 1;
        ELSE
            SET v_AbnormalCountOfBottles = v_AbnormalCountOfBottles + 1;
        END IF;

        SET v_TotCountOfBottles = v_TotCountOfBottles + 1;

        SET v_BottleInfo = JSON_ARRAY_APPEND(
            v_BottleInfo, '$', 
            JSON_OBJECT(
                'BottleID', v_BottleID,
                'PositionOfInputParameter', v_Position,
                'PositionOfDB', v_DBPosition
            )
        );

        SET v_CurrentIndex = v_CurrentIndex + 1;
    END WHILE;

    -- Set the JSON output
    SET jsonOutput = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_SenderController,
        'TotCountOfBottles', v_TotCountOfBottles,
        'NormalCountOfBottles', v_NormalCountOfBottles,
        'AbnormalCountOfBottles', v_AbnormalCountOfBottles,
        'BottleInfo', v_BottleInfo,
        'error_msg', v_ErrorMsg
    );

END //
DELIMITER ;

-- 151. RequestNumberOfEmptyBottle                     반출입기에서 추출가능한 빈병수량요청
-- GPT prompt
-- 입력 파라메터는 json type. 내용은 아래와 같음.
--       {
--          "EqpGroupID" : '1',            // 설비군 (InOutBottle)
--          "EqpSeqNo" : 1,                // 정의하지 않으면 1로 추정함. 생략가능
--       }
-- 출력 파라메터는 json type. 내용은 아래와 같음.
--       {
--          "status_code" : 200,
--  		"sender_controller" : "InOutBottle" or "DB_Manager",
--			"NumberOfEmptyBottle" : 20,
--          "error_msg" : "None"
--       }	  
-- CREATE TABLE tBottleInfoOfHoleAtInOutBottle (
--    EqpSeqNo                 CHAR(1) NOT NULL,       -- 호기 (1부터 시작)
--    ZoneName                 CHAR(7),                -- 좌:Empty, 우:Filled
--    Position                 CHAR(4) NOT NULL,       -- Stocker에서 위치정보
--    UsageFlag                CHAR(1) default 'O',    -- 'O':사용가능, 'X':사용불가
--    AllocationPriority       TINYINT default 1,      -- 1 부터 시작
--    EventTime                DATETIME,               -- Event Time
--    BottleID                 CHAR(15)                -- Bottle ID
-- ) ON [Process];
-- tBottleInfoOfHoleAtInOutBottle table의 
-- ZoneName이 'Empty'일때 BottleID값이 null아닌 record의 수치를  NumberOfEmptyBottle assign한다.
-- maria db를 사용하고 있고, 예외 처리를 위한 DECLARE ... HANDLER 구문추가해줘.
-- Error  발생하면 관련내용을 insert하는 stored procedure 만들어줘.
DELIMITER //
CREATE PROCEDURE spReadNumberOfEmptyBottles(IN jsonInput JSON, OUT jsonOutput JSON)
BEGIN
    DECLARE v_EqpGroupID CHAR(1);
    DECLARE v_EqpSeqNo CHAR(1) DEFAULT '1';
    DECLARE v_NumberOfEmptyBottle INT;
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_ErrorMsg VARCHAR(255) DEFAULT 'None';
    DECLARE v_ErrorText VARCHAR(255);
    DECLARE v_ErrorCode INT;
    DECLARE v_SenderController VARCHAR(50) DEFAULT 'InOutBottle';

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_ErrorText = MESSAGE_TEXT;
        GET DIAGNOSTICS CONDITION 1 v_ErrorCode = MYSQL_ERRNO;

        SET v_StatusCode = 500;
        SET v_ErrorMsg = 'Database error';

        -- Insert error details into tProcSqlError table
        INSERT INTO tProcSqlError (ProcedureName, ErrorCode, ErrorMessage) 
        VALUES ('spReadNumberOfEmptyBottles', v_ErrorCode, v_ErrorText);

        SET jsonOutput = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_SenderController,
            'NumberOfEmptyBottle', NULL,
            'error_msg', v_ErrorMsg
        );
        ROLLBACK;
    END;

    -- Extract values from JSON input
    SET v_EqpGroupID = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.EqpGroupID'));

    -- Check if EqpSeqNo is provided, if not set to default 1
    IF JSON_CONTAINS_PATH(jsonInput, 'one', '$.EqpSeqNo') THEN
        SET v_EqpSeqNo = CAST(JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.EqpSeqNo')) AS UNSIGNED);
    END IF;

    -- Count the number of empty bottles in the empty bottle zone
    SELECT COUNT(*)
    INTO v_NumberOfEmptyBottle
    FROM tBottleInfoOfHoleAtInOutBottle
    WHERE ZoneName = 'Empty' AND EqpSeqNo = v_EqpSeqNo AND BottleID IS NOT NULL;

    -- Set the JSON output
    SET jsonOutput = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_SenderController,
        'NumberOfEmptyBottle', v_NumberOfEmptyBottle,
        'error_msg', v_ErrorMsg
    );

END //
DELIMITER ;

-- 152. RequestNumberOfFilledBottle                    반출입기에서 추출가능한 실병수량요청
-- GPT prompt
-- 입력 파라메터는 json type. 내용은 아래와 같음.
--       {
--          "EqpGroupID" : '1',            // 설비군 (InOutBottle)
--          "EqpSeqNo" : 1,                // 정의하지 않으면 1로 추정함. 생략가능
--       }
-- 출력 파라메터는 json type. 내용은 아래와 같음.
--       {
--          "status_code" : 200,
--  		"sender_controller" : "InOutBottle" or "DB_Manager",
--			"NumberOfFilledBottle" : 20,
--          "error_msg" : "None"
--       }	  
-- CREATE TABLE tBottleInfoOfHoleAtInOutBottle (
--    EqpSeqNo                 CHAR(1) NOT NULL,       -- 호기 (1부터 시작)
--    ZoneName                 CHAR(7),                -- 좌:Empty, 우:Filled
--    Position                 CHAR(4) NOT NULL,       -- Stocker에서 위치정보
--    UsageFlag                CHAR(1) default 'O',    -- 'O':사용가능, 'X':사용불가
--    AllocationPriority       TINYINT default 1,      -- 1 부터 시작
--    EventTime                DATETIME,               -- Event Time
--    BottleID                 CHAR(15)                -- Bottle ID
-- ) ON [Process];
-- tBottleInfoOfHoleAtInOutBottle table의 
-- ZoneName이 'Empty'일때 BottleID값이 null아닌 record의 수치를  NumberOfFilledBottle assign한다.
-- maria db를 사용하고 있고, 예외 처리를 위한 DECLARE ... HANDLER 구문추가해줘.
-- Error  발생하면 관련내용을 insert하는 stored procedure 만들어줘.
DELIMITER //
CREATE PROCEDURE spReadNumberOfFilledBottles(IN jsonInput JSON, OUT jsonOutput JSON)
BEGIN
    DECLARE v_EqpGroupID CHAR(1);
    DECLARE v_EqpSeqNo CHAR(1) DEFAULT '1';
    DECLARE v_NumberOfFilledBottle INT;
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_ErrorMsg VARCHAR(255) DEFAULT 'None';
    DECLARE v_ErrorText VARCHAR(255);
    DECLARE v_ErrorCode INT;
    DECLARE v_SenderController VARCHAR(50) DEFAULT 'InOutBottle';

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_ErrorText = MESSAGE_TEXT;
        GET DIAGNOSTICS CONDITION 1 v_ErrorCode = MYSQL_ERRNO;

        SET v_StatusCode = 500;
        SET v_ErrorMsg = 'Database error';

        -- Insert error details into tProcSqlError table
        INSERT INTO tProcSqlError (ProcedureName, ErrorCode, ErrorMessage) 
        VALUES ('spReadNumberOfFilledBottles', v_ErrorCode, v_ErrorText);

        SET jsonOutput = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_SenderController,
            'NumberOfFilledBottle', NULL,
            'error_msg', v_ErrorMsg
        );
        ROLLBACK;
    END;

    -- Extract values from JSON input
    SET v_EqpGroupID = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.EqpGroupID'));

    -- Check if EqpSeqNo is provided, if not set to default 1
    IF JSON_CONTAINS_PATH(jsonInput, 'one', '$.EqpSeqNo') THEN
        SET v_EqpSeqNo = CAST(JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.EqpSeqNo')) AS UNSIGNED);
    END IF;

    -- Count the number of filled bottles in the filled bottle zone
    SELECT COUNT(*)
    INTO v_NumberOfFilledBottle
    FROM tBottleInfoOfHoleAtInOutBottle
    WHERE ZoneName = 'Filled' AND BottleID IS NOT NULL AND EqpSeqNo = v_EqpSeqNo;

    -- Set the JSON output
    SET jsonOutput = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_SenderController,
        'NumberOfFilledBottle', v_NumberOfFilledBottle,
        'error_msg', v_ErrorMsg
    );

END //
DELIMITER ;

-- 153. ExtractProperEmptyBottle                       반출입기에서 적정(실험의뢰자에 의해 생성된정보) 빈병정보를 요청후 빈병을 추출한다 ----- Suitable => Proper
-- GPT prompt
-- 입력 파라메터는 json type. 내용은 아래와 같음.
--       {
--          "EqpGroupID" :  '1',           // 설비군 (InOutBottle)
--          "EqpSeqNo" : 1,                // 정의하지 않으면 1로 추정함. 생략가능
--          "Employee_ID" : "13579",
--          "ProjectNum" : "prj97531"
--       }
-- 출력 파라메터는 json type. 내용은 아래와 같음.
--       {
--          "status_code" : 200,
--          "sender_controller" : "DB_Manager",    //
--          "TotCountOfEmptyBottlePack" : 5
--          "EmptyBottleInfo" : [
-- 		       {"1011" : "bot_0132"},
--                 ...
--             {"1015" : "bot_0136"}
--          ],
--          "error_msg" : "None"
--       }	  
-- Employee_ID는 vBottleInfoWithPosition 의 ExperimentRequestID
-- ProjectNum는 vBottleInfoWithPosition 의 ProjectNum record 에서 position, bottle ID를 찾아서 출력파라메터를 완성해줘.
-- maria db를 사용하고 있고, 예외 처리를 위한 DECLARE ... HANDLER 구문추가해줘.
-- Error  발생하면 관련내용을 insert하는 stored procedure 만들어줘.
DELIMITER //
CREATE PROCEDURE spGetEmptyBottlePackInfo(IN jsonInput JSON, OUT jsonOutput JSON)
BEGIN
    DECLARE v_EqpGroupID CHAR(1);
    DECLARE v_EqpSeqNo CHAR(1) DEFAULT '1';
    DECLARE v_EmployeeID NVARCHAR(10);
    DECLARE v_ProjectNum NVARCHAR(10);
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_ErrorMsg VARCHAR(255) DEFAULT 'None';
    DECLARE v_ErrorText VARCHAR(255);
    DECLARE v_ErrorCode INT;
    DECLARE v_SenderController VARCHAR(50) DEFAULT 'DB_Manager';
    DECLARE v_TotCountOfEmptyBottlePack INT DEFAULT 0;
    DECLARE v_EmptyBottleInfo JSON;
    DECLARE v_Position VARCHAR(4);
    DECLARE v_BottleID CHAR(15);
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_ErrorText = MESSAGE_TEXT;
        GET DIAGNOSTICS CONDITION 1 v_ErrorCode = MYSQL_ERRNO;

        SET v_StatusCode = v_ErrorCode;
        SET v_ErrorMsg = v_ErrorText;

        -- Insert error details into tProcSqlError table
        INSERT INTO tProcSqlError (ProcedureName, ErrorCode, ErrorMessage) 
        VALUES ('spGetEmptyBottlePackInfo', v_ErrorCode, v_ErrorText);

        SET jsonOutput = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_SenderController,
            'TotCountOfEmptyBottlePack', NULL,
            'EmptyBottleInfo', NULL,
            'error_msg', v_ErrorMsg
        );
        ROLLBACK;
    END;

    -- Extract values from JSON input
    SET v_EqpGroupID = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.EqpGroupID'));
    SET v_EmployeeID = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.Employee_ID'));
    SET v_ProjectNum = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.ProjectNum'));

    -- Check if EqpSeqNo is provided, if not set to default 1
    IF JSON_CONTAINS_PATH(jsonInput, 'one', '$.EqpSeqNo') THEN
        SET v_EqpSeqNo = CAST(JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.EqpSeqNo')) AS UNSIGNED);
    END IF;

    -- Get empty bottle information
    SELECT COUNT(*)
    INTO v_TotCountOfEmptyBottlePack
    FROM vBottleInfoWithPosition
    WHERE ExperimentRequestID = v_EmployeeID 
      AND ProjectNum = v_ProjectNum
      AND ZoneName = 'Empty';

    SELECT JSON_ARRAYAGG(JSON_OBJECT(Position, BottleID))
    INTO v_EmptyBottleInfo
    FROM vBottleInfoWithPosition
    WHERE ExperimentRequestID = v_EmployeeID 
      AND ProjectNum = v_ProjectNum
      AND ZoneName = 'Empty';

    -- Set the JSON output
    SET jsonOutput = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_SenderController,
        'TotCountOfEmptyBottlePack', v_TotCountOfEmptyBottlePack,
        'EmptyBottleInfo', v_EmptyBottleInfo,
        'error_msg', v_ErrorMsg
    );

END //
DELIMITER ;

-- 154. RequestProperFillledBottle                     반출입기에서 적정(실험의뢰자에 의해 채취한 실병정보) 실병정보를 요청한다.
-- GPT prompt
-- 1. 입력 파라메터는 json type. 내용은 아래와 같음.
--       {
--          "EqpGroupID" : 1               // 설비군
--          "EqpSeqNo" : 1,                // 정의하지 않으면 1로 추정함. 생략가능
--       }
-- 출력 파라메터는 json type. 내용은 아래와 같음.
--       {
--          "status_code" : 200,
--
--          "error_msg" : "None"
--       }	  
--
-- maria db를 사용하고 있고, 예외 처리를 위한 DECLARE ... HANDLER 구문추가해줘.
-- Error  발생하면 관련내용을 insert하는 stored procedure 만들어줘.

-- 155. ExtractProperFillledBottle                     반출입기에서 적정 Real Bottle을 추출한다 ----- RealBottle => FilledBottle
-- GPT prompt
-- 입력 파라메터는 json type. 내용은 아래와 같음.
--       {
--          "EqpGroupID" : 1               // 설비군
--          "EqpSeqNo" : 1,                // 정의하지 않으면 1로 추정함. 생략가능
--          "UsedPosition" : "1011, 1021", // Option, 입력되지 않을수 있음
--          "NotUsedPosition" : "2021"     // Option, 입력되지 않을수 있음
--       }
-- 출력 파라메터는 json type. 내용은 아래와 같음.
--       {
--          "status_code" : 200,
-- 			"sender_controller" : "InOutBottle" and "DB_Manager".
--          "error_msg" : "None"
--       }	  
--
-- maria db를 사용하고 있고, 예외 처리를 위한 DECLARE ... HANDLER 구문추가해줘.
-- Error  발생하면 관련내용을 insert하는 stored procedure 만들어줘.

-- 181. SetUsageStatus4Hole                            Hole 사용여부 정의한다
-- GPT prompt
-- 입력 파라메터는 json type. 내용은 아래와 같음.
--       {
--          "EqpGroupID" : 1               // 설비군
--          "EqpSeqNo" : 1,                // 정의하지 않으면 1로 추정함. 생략가능
--       }
-- 출력 파라메터는 json type. 내용은 아래와 같음.
--       {
--          "status_code" : 200,
--
--          "error_msg" : "None"
--       }	  
-- CREATE TABLE tBottleInfoOfHoleAtInOutBottle (
--    EqpSeqNo                 CHAR(1) NOT NULL,       -- 호기 (1부터 시작)
--    ZoneName                 CHAR(7),                -- 좌:Empty, 우:Filled
--    Position                 CHAR(4) NOT NULL,       -- Stocker에서 위치정보
--    UsageFlag                CHAR(1) default 'O',    -- 'O':사용가능, 'X':사용불가
--    AllocationPriority       TINYINT default 1,      -- 1 부터 시작
--    EventTime                DATETIME,               -- Event Time
--    BottleID                 CHAR(15)                -- Bottle ID
-- ) ON [Process];
-- tBottleInfoOfHoleAtInOutBottle table의 
-- 입력파라메터에서 입력된 UsedPosition 값이 있으면 UsageFlag값을 'O' update해줘.
-- 입력파라메터에서 입력된 NotUsedPosition 값이 있으면 UsageFlag값을 'X' update해줘.
-- maria db를 사용하고 있고, 예외 처리를 위한 DECLARE ... HANDLER 구문추가해줘.
-- Error  발생하면 관련내용을 insert하는 stored procedure 만들어줘.
-- 2. UsedPosition, NotUsedPosition에 여러개의 position값이 들어올수 있음.
--
DELIMITER //
CREATE PROCEDURE spUpdateUsageFlag(IN jsonInput JSON, OUT jsonOutput JSON)
BEGIN
    DECLARE v_EqpGroupID CHAR(1);
    DECLARE v_EqpSeqNo CHAR(1) DEFAULT '1';
    DECLARE v_UsedPosition VARCHAR(255);
    DECLARE v_NotUsedPosition VARCHAR(255);
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_ErrorMsg VARCHAR(255) DEFAULT 'None';
    DECLARE v_ErrorText VARCHAR(255);
    DECLARE v_ErrorCode INT;
    DECLARE v_SenderController VARCHAR(50) DEFAULT 'DB_Manager';
    DECLARE v_Position VARCHAR(4);
    DECLARE v_PosIndex INT DEFAULT 1;
    DECLARE v_PosCount INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_ErrorText = MESSAGE_TEXT;
        GET DIAGNOSTICS CONDITION 1 v_ErrorCode = MYSQL_ERRNO;

        SET v_StatusCode = v_ErrorCode;
        SET v_ErrorMsg = v_ErrorText;

        -- Insert error details into tProcSqlError table
        INSERT INTO tProcSqlError (ProcedureName, ErrorCode, ErrorMessage) 
        VALUES ('spUpdateUsageFlag', v_ErrorCode, v_ErrorText);

        SET jsonOutput = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_SenderController,
            'error_msg', v_ErrorMsg
        );
        ROLLBACK;
    END;

    -- Extract values from JSON input
    SET v_EqpGroupID = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.EqpGroupID'));

    -- Check if EqpSeqNo is provided, if not set to default 1
    IF JSON_CONTAINS_PATH(jsonInput, 'one', '$.EqpSeqNo') THEN
        SET v_EqpSeqNo = CAST(JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.EqpSeqNo')) AS UNSIGNED);
    END IF;

    -- Update UsedPosition
    IF JSON_CONTAINS_PATH(jsonInput, 'one', '$.UsedPosition') THEN
        SET v_UsedPosition = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.UsedPosition'));
        SET v_PosCount = JSON_LENGTH(JSON_ARRAYAGG(v_UsedPosition));

        WHILE v_PosIndex <= v_PosCount DO
            SET v_Position = SUBSTRING_INDEX(SUBSTRING_INDEX(v_UsedPosition, ',', v_PosIndex), ',', -1);
            UPDATE tBottleInfoOfHoleAtInOutBottle
            SET UsageFlag = 'O'
            WHERE Position = v_Position
            AND EqpSeqNo = v_EqpSeqNo;
            SET v_PosIndex = v_PosIndex + 1;
        END WHILE;
    END IF;

    -- Update NotUsedPosition
    SET v_PosIndex = 1; -- Reset the index for the next loop
    IF JSON_CONTAINS_PATH(jsonInput, 'one', '$.NotUsedPosition') THEN
        SET v_NotUsedPosition = JSON_UNQUOTE(JSON_EXTRACT(jsonInput, '$.NotUsedPosition'));
        SET v_PosCount = JSON_LENGTH(JSON_ARRAYAGG(v_NotUsedPosition));

        WHILE v_PosIndex <= v_PosCount DO
            SET v_Position = SUBSTRING_INDEX(SUBSTRING_INDEX(v_NotUsedPosition, ',', v_PosIndex), ',', -1);
            UPDATE tBottleInfoOfHoleAtInOutBottle
            SET UsageFlag = 'X'
            WHERE Position = v_Position
            AND EqpSeqNo = v_EqpSeqNo;
            SET v_PosIndex = v_PosIndex + 1;
        END WHILE;
    END IF;

    -- Set the JSON output
    SET jsonOutput = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_SenderController,
        'error_msg', v_ErrorMsg
    );

END //
DELIMITER ;




-- 201. Stocker 설비상태를 요청한다.
-- GPT prompt
--     - 기존에 만들어진 spRequestStatusAtEquipment 저장 프로시저를 호출하여 EqpGroupID = '2' 및 EqpSeqNo = '1' 값을 전달하는 새로운 저장 프로시저를 작성해줘.
--       maria db를 사용하고 있고, 예외 처리를 위한 DECLARE ... HANDLER 구문추가해줘.
DELIMITER $$
CREATE PROCEDURE spRequestStatusAtStocker2DB()
BEGIN
    DECLARE v_InputJson JSON;
    DECLARE v_Result JSON;

    -- 입력 JSON 생성
    SET v_InputJson = JSON_OBJECT(
        'EqpGroupID', '2',
        'EqpSeqNo', '1'
    );

    -- 예외 처리 시작
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- 오류 발생 시, 오류 메시지를 포함한 결과를 반환합니다.
        SET v_Result = JSON_OBJECT(
            'status_code', 500,
            'sender_controller', 'DB_Manager',
            'error_msg', 'An error occurred while retrieving equipment status.'
        );

        SELECT v_Result AS result;
        ROLLBACK;
    END;

    START TRANSACTION;

    -- spRequestStatusAtEquipment 저장 프로시저 호출
    CALL spRequestStatusAtEquipment(v_InputJson, @outputJson);

    -- 결과 반환
    SELECT @outputJson AS result;

    COMMIT;
END$$
DELIMITER ;


-- 211. Stocker에 입고완료메세지(#21 공정시작)
-- GPT prompt
--     - 기존에 만들어진 spLoadComp4BottleAtEquipment 저장 프로시저를 호출하여 EqpGroupID = '2' 및 EqpSeqNo = '1' 값을 전달하는 새로운 저장 프로시저를 작성해줘.
--       maria db를 사용하고 있고, 예외 처리를 위한 DECLARE ... HANDLER 구문추가해줘.



-- 225. Stocker에서 Hole 존재하는 bottle정보와 DB에 있는 정보를 비교한다
-- GPT prompt
--     - stored procedure json type 입력 parameter는 아래와 같은 형식.
--     - json type return value는 아래와 같은 형식.
--     - tProcBottle table에서 입력된 bottle id의 position 정보가 일치하면 NormalCountOfBottles 1씩 증가.
--       틀리면 AbnormalCountOfBottles 1씩 증가하고 틀린 정보를 생성하는 stored procedure 만들어줘.
--       maria DB 사용중. 예외 처리를 위한 DECLARE ... HANDLER 구문추가해줘.
-- 
DELIMITER $$
CREATE PROCEDURE spCompareEqpBottleInfo2DB_BottleInfoAtStocker (
    IN p_InputJson JSON,
    OUT p_OutputJson JSON
)
BEGIN
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_ErrorMsg NVARCHAR(255) DEFAULT 'None';
    DECLARE v_TotCountOfBottles INT;
    DECLARE v_NormalCountOfBottles INT DEFAULT 0;
    DECLARE v_AbnormalCountOfBottles INT DEFAULT 0;
    DECLARE v_ResultBottlesJson JSON;

    -- 예외 처리 시작
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_StatusCode = MYSQL_ERRNO, 
            v_ErrorMsg = MESSAGE_TEXT;
        
        SET p_OutputJson = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', 'Stocker_Controller',
            'TotCountOfBottles', 0,
            'NormalCountOfBottles', 0,
            'AbnormalCountOfBottles', 0,
            'BottleInfo', JSON_ARRAY(),
            'error_msg', v_ErrorMsg
        );
        ROLLBACK;
    END;

    START TRANSACTION;

    -- Temporary tables for processing
    CREATE TEMPORARY TABLE IF NOT EXISTS TempInputBottles (
        BottleID NVARCHAR(50),
        Position NVARCHAR(50)
    );

    CREATE TEMPORARY TABLE IF NOT EXISTS TempResultBottles (
        BottleID NVARCHAR(50),
        PositionOfInputParameter NVARCHAR(50),
        PositionOfDB NVARCHAR(50)
    );

    -- Parse the input JSON
    INSERT INTO TempInputBottles (BottleID, Position)
    SELECT 
        JSON_UNQUOTE(JSON_EXTRACT(Bottle.value, '$.BottleID')) AS BottleID,
        JSON_UNQUOTE(JSON_EXTRACT(Bottle.value, '$.Position')) AS Position
    FROM JSON_TABLE(p_InputJson, '$.BottleInfo[*]' COLUMNS (
        Bottle JSON PATH '$'
    )) AS Bottle;

    SET v_TotCountOfBottles = (SELECT COUNT(*) FROM TempInputBottles);

    -- Check each bottle
    INSERT INTO TempResultBottles (BottleID, PositionOfInputParameter, PositionOfDB)
    SELECT 
        i.BottleID, 
        i.Position AS PositionOfInputParameter, 
        p.Position AS PositionOfDB
    FROM TempInputBottles i
    LEFT JOIN tProcBottle p ON i.BottleID = p.BottleID;

    -- Calculate counts
    SELECT 
        SUM(CASE WHEN PositionOfInputParameter = PositionOfDB THEN 1 ELSE 0 END),
        SUM(CASE WHEN PositionOfInputParameter <> PositionOfDB THEN 1 ELSE 0 END)
    INTO v_NormalCountOfBottles, v_AbnormalCountOfBottles
    FROM TempResultBottles;

    -- Create the output JSON
    SELECT JSON_ARRAYAGG(
        JSON_OBJECT(
            'BottleID', BottleID,
            'PositionOfInputParameter', PositionOfInputParameter,
            'PositionOfDB', COALESCE(PositionOfDB, 'null')
        )
    ) INTO v_ResultBottlesJson
    FROM TempResultBottles;

    SET p_OutputJson = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', 'Stocker_Controller',
        'TotCountOfBottles', v_TotCountOfBottles,
        'NormalCountOfBottles', v_NormalCountOfBottles,
        'AbnormalCountOfBottles', v_AbnormalCountOfBottles,
        'BottleInfo', v_ResultBottlesJson,
        'error_msg', v_ErrorMsg
    );

    COMMIT;

    -- Cleanup
    DROP TEMPORARY TABLE IF EXISTS TempInputBottles;
    DROP TEMPORARY TABLE IF EXISTS TempResultBottles;
END$$
DELIMITER ;

-- 231. Stocker에서 추출할 우선순위별 Bottle Pack 수량요청
-- GPT prompt
--     - json type return value는 아래와 같은 형식.
--     - tProcBottle table에서 CurrEqpGroupID = '3'인 것중 DispatchingPriority 내림차순, RequestDate 오름차순.
--       PackID로 group by수행후 첫번째 record의 Position 정보를 먼저찾고,
--       '1'이면 "Zone"에 "Left", "2"이면 "Zone"에 "Right", 그 이외일때는 "Zone"에 "Error"로 처리.
--       CurrEqpGroupID = '3'이고 DB field Position의 첫째 자리와  위에서 찾은 Position의 첫번째 자리일치하는 
--       record중 최대 5개 PackID와 Pack의 bottle 수량을 구하는 stored procedure 만들어줘.
--       예외 처리를 위한 DECLARE ... HANDLER 구문추가해줘.
--     - stored procedure where 조건에 다음 내용추가해줘. 현재시간이 > JudgeLimitTm.
--
DELIMITER $$
CREATE PROCEDURE spExtractSuitableBottlePackCountAtStocker (
    OUT p_OutputJson JSON
)
BEGIN
    DECLARE v_FirstPosition NVARCHAR(50);
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_ErrorMsg NVARCHAR(255) DEFAULT 'None';
    DECLARE v_TotCountOfBottlePack INT;
    DECLARE v_Zone NVARCHAR(10);
    DECLARE v_BottleInfo JSON;
    DECLARE v_CurrentTime DATETIME;

    -- 현재 시간을 가져옴
    SET v_CurrentTime = NOW();

    -- 예외 처리 시작
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_StatusCode = MYSQL_ERRNO, 
            v_ErrorMsg = MESSAGE_TEXT;
        
        SET p_OutputJson = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', 'DB_Manager',
            'TotCountOfBottlePack', 0,
            'Zone', 'Error',
            'BottleInfo', JSON_ARRAY(),
            'error_msg', v_ErrorMsg
        );
        ROLLBACK;
    END;

    START TRANSACTION;

    -- Temporary table to store intermediate results
    CREATE TEMPORARY TABLE TempResult (
        PackID NVARCHAR(50),
        TotalBottleCountOfPack INT
    );

    -- Get the first Position based on the given order and group by PackID
    SELECT Position
    INTO v_FirstPosition
    FROM (
        SELECT Position
        FROM tProcBottle
        WHERE CurrEqpGroupID = '3' AND v_CurrentTime > JudgeLimitTm
        GROUP BY Position, PackID
        ORDER BY MAX(DispatchingPriority) DESC, MIN(RequestDate) ASC
        LIMIT 1
    ) AS SubQuery;

    -- Determine Zone based on the first character of the Position
    SET v_Zone = CASE 
                    WHEN LEFT(v_FirstPosition, 1) = '1' THEN 'Left'
                    WHEN LEFT(v_FirstPosition, 1) = '2' THEN 'Right'
                    ELSE 'Error' 
                END;

    -- Group by PackID and get the bottle count, limit to 5 packs
    INSERT INTO TempResult (PackID, TotalBottleCountOfPack)
    SELECT PackID, COUNT(*)
    FROM tProcBottle
    WHERE CurrEqpGroupID = '3' AND LEFT(Position, 1) = LEFT(v_FirstPosition, 1) AND v_CurrentTime > JudgeLimitTm
    GROUP BY PackID
    LIMIT 5;

    -- Calculate total count of bottle packs
    SELECT COUNT(*)
    INTO v_TotCountOfBottlePack
    FROM TempResult;

    -- Build the JSON output for BottleInfo
    SELECT JSON_ARRAYAGG(
        JSON_OBJECT(
            'PackID', PackID,
            'TotalBottleCountOfPack', TotalBottleCountOfPack
        )
    )
    INTO v_BottleInfo
    FROM TempResult;

    SET p_OutputJson = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', 'DB_Manager',
        'TotCountOfBottlePack', v_TotCountOfBottlePack,
        'Zone', v_Zone,
        'BottleInfo', v_BottleInfo,
        'error_msg', v_ErrorMsg
    );

    COMMIT;

    -- Clean up
    DROP TEMPORARY TABLE IF EXISTS TempResult;
END$$
DELIMITER ;


-- 232. Stocker에서 추출할 적정 Bottle Pack 정보요청 
-- GPT prompt
--     - stored procedure json type 입력 parameter는 아래와 같은 형식.
--     - json type return value는 아래와 같은 형식.
--     - tProcBottle table에서 입력된 PackID와 일치하는 BottleID와 position 정보를 postion 순서대로 구하는 stored procedure 만들어줘.
--       예외 처리를 위한 DECLARE ... HANDLER 구문추가해줘.
--
DELIMITER $$
CREATE PROCEDURE spGetBottleInfoByPackID (
    IN p_InputJson JSON,
    OUT p_OutputJson JSON
)
BEGIN
    DECLARE v_PackID NVARCHAR(50);
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_ErrorMsg NVARCHAR(255) DEFAULT 'None';
    DECLARE v_TotCountOfBottlePack INT;
    DECLARE v_BottleInfo JSON;

    -- 예외 처리 시작
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_StatusCode = MYSQL_ERRNO, 
            v_ErrorMsg = MESSAGE_TEXT;
        
        SET p_OutputJson = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', 'DB_Manager',
            'TotCountOfBottlePack', 0,
            'BottleInfo', JSON_ARRAY(),
            'error_msg', v_ErrorMsg
        );
        ROLLBACK;
    END;

    START TRANSACTION;

    -- JSON 파라미터에서 값 추출
    SET v_PackID = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.PackID'));

    -- Check if the PackID is valid
    IF v_PackID IS NULL THEN
        SET v_StatusCode = 400;
        SET v_ErrorMsg = 'Invalid input: PackID is required.';
        SET p_OutputJson = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', 'DB_Manager',
            'TotCountOfBottlePack', 0,
            'BottleInfo', JSON_ARRAY(),
            'error_msg', v_ErrorMsg
        );
        ROLLBACK;
        LEAVE spGetBottleInfoByPackID;
    END IF;

    -- Temporary table to store intermediate results
    CREATE TEMPORARY TABLE TempResultBottles (
        BottleID NVARCHAR(50),
        Position NVARCHAR(50)
    );

    -- Retrieve bottle information
    INSERT INTO TempResultBottles (BottleID, Position)
    SELECT BottleID, Position
    FROM tProcBottle
    WHERE PackID = v_PackID
    ORDER BY Position;

    -- Calculate total count of bottles in the pack
    SELECT COUNT(*)
    INTO v_TotCountOfBottlePack
    FROM TempResultBottles;

    -- Build the JSON output for BottleInfo
    SELECT JSON_ARRAYAGG(
        JSON_OBJECT(
            'BottleID', BottleID,
            'Position', Position
        )
    )
    INTO v_BottleInfo
    FROM TempResultBottles;

    SET p_OutputJson = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', 'DB_Manager',
        'TotCountOfBottlePack', v_TotCountOfBottlePack,
        'BottleInfo', v_BottleInfo,
        'error_msg', v_ErrorMsg
    );

    COMMIT;

    -- Clean up
    DROP TEMPORARY TABLE IF EXISTS TempResultBottles;
END$$
DELIMITER ;



















-- 901. spUpdateStatusAtEquipment        장비상태를 변경한다. (Idle-->Run, Run-->Idle)
-- ChangeEqpStatus token event에 대한 처리
-- 장비상태를 변경한다. (Idle-->Run, Run-->Idle)
-- 사용법
--     
-- RETURN
-- {
--    "status_code": 200,
--    "sender_controller": "DB_Manager",
--    "error_msg": "None"
-- }
DELIMITER $$
CREATE PROCEDURE spUpdateStatusAtEquipment (
    IN p_InputJson JSON,
    OUT p_OutputJson JSON
)
BEGIN
    DECLARE v_EqpGroupID CHAR(1);
    DECLARE v_EqpSeqNo CHAR(1);
    DECLARE v_NewStatus NVARCHAR(10);
    DECLARE v_CurrentTime DATETIME;
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_SenderController VARCHAR(20) DEFAULT 'DB_Manager';
    DECLARE v_ErrorMsg VARCHAR(100) DEFAULT 'None';
    DECLARE v_JsonResult JSON;

    -- JSON 파라미터에서 값 추출
    SET v_EqpGroupID = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.EqpGroupID'));
    SET v_EqpSeqNo = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.EqpSeqNo'));
    SET v_NewStatus = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.NewStatus'));

    -- 예외 처리 시작
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_StatusCode = MYSQL_ERRNO, 
            v_ErrorMsg = MESSAGE_TEXT;
        
        SET v_JsonResult = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_SenderController,
            'error_msg', v_ErrorMsg
        );

        SET p_OutputJson = v_JsonResult;
        ROLLBACK;
    END;

    START TRANSACTION;

    -- 현재 시간을 가져옴
    SET v_CurrentTime = NOW();

    -- tMstEqp 테이블의 EqpStatus와 EventTime을 업데이트
    UPDATE tMstEqp
    SET EqpStatus = v_NewStatus,
        EventTime = v_CurrentTime
    WHERE EqpGroupID = v_EqpGroupID
      AND EqpSeqNo = v_EqpSeqNo;

    COMMIT;

    -- JSON 형식으로 결과 반환
    SET v_JsonResult = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_SenderController,
        'error_msg', v_ErrorMsg
    );

    SET p_OutputJson = v_JsonResult;
END$$
DELIMITER ;


-- 904. spRequestStatusAtEquipment       장비상태를 가져온다
-- ReqAnalysisEqpStatus token event에 대한 처리
-- 장비상태를 가져온다
-- 사용법
--    CALL spRequestStatusAtEquipment();
--
-- RETURN
-- {
--    "status_code": 200,
--    "sender_controller": "DB_Manager",
--    "eqp_status": "Run",
--    "process_status": "UnloadReq",
--    "error_msg": "None"
-- }
DELIMITER $$
CREATE PROCEDURE spRequestStatusAtEquipment(
    IN p_InputJson JSON
)
BEGIN
    DECLARE v_EqpGroupID NVARCHAR(10);
    DECLARE v_EqpSeqNo NVARCHAR(10);
    DECLARE v_EqpStatus NVARCHAR(10);
    DECLARE v_ProcessStatus NVARCHAR(12);
    DECLARE v_ErrorMsg NVARCHAR(100) DEFAULT 'None';
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_JsonResult JSON;

    -- JSON 파라미터에서 값을 추출
    SET v_EqpGroupID = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.EqpGroupID'));
    SET v_EqpSeqNo = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.EqpSeqNo'));

    -- 예외 처리 시작
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_StatusCode = MYSQL_ERRNO, 
            v_ErrorMsg = MESSAGE_TEXT;
        
        SET v_JsonResult = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', 'DB_Manager',
            'error_msg', v_ErrorMsg
        );

        SELECT v_JsonResult AS result;
        ROLLBACK;
    END;

    START TRANSACTION;

    -- tMstEqp 테이블에서 EqpStatus와 ProcessStatus를 가져옴
    SELECT EqpStatus, ProcessStatus
    INTO v_EqpStatus, v_ProcessStatus
    FROM tMstEqp
    WHERE EqpGroupID = v_EqpGroupID
      AND EqpSeqNo = v_EqpSeqNo
    LIMIT 1;

    COMMIT;

    -- JSON 형식으로 결과 반환
    SET v_JsonResult = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', 'DB_Manager',
        'eqp_status', v_EqpStatus,
        'process_status', v_ProcessStatus,
        'error_msg', v_ErrorMsg
    );

    SELECT v_JsonResult AS result;
END$$
DELIMITER ;


-- 905. spRetrieveAllEquipmentStatuses   모든 장비상태를 가져온다
-- ReqAllEqpStatus token event에 대한 처리
-- 모든 장비상태를 가져온다
-- 사용법
--    CALL spRetrieveAllEquipmentStatuses();
--
-- RETURN
-- {
--    "status_code": 200,
--    "sender_controller": "DB_Manager",
--    "total_cnt_of_eqp": 5,
--    "eqp_status": [
--       { "No_1": {
--            "EqpGroupID": "1", "EqpSeqNo": "1", "ProcessStatus": "UnloadReq", "EqpStatus": "Idle"}
--       },
--       { "No_2": {
--            "EqpGroupID": "2", "EqpSeqNo": "1", "ProcessStatus": "Idle", "EqpStatus": "Run"}
--       },
--       ...
--       { "No_5": {
--            "EqpGroupID": "5", "EqpSeqNo": "1", "ProcessStatus": "LoadComp", "EqpStatus": "Idle"}
--       }
--    ],
--    "error_msg": "None"
-- }
DELIMITER $$
CREATE PROCEDURE spRetrieveAllEquipmentStatuses()
BEGIN
    DECLARE v_TotalCntOfEqp INT DEFAULT 0;
    DECLARE v_ErrorMsg NVARCHAR(100) DEFAULT 'None';
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_SenderController VARCHAR(20) DEFAULT 'DB_Manager';
    DECLARE v_JsonResult JSON;

    -- 예외 처리 시작
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_StatusCode = MYSQL_ERRNO, 
            v_ErrorMsg = MESSAGE_TEXT;
        
        SET v_JsonResult = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_SenderController,
            'error_msg', v_ErrorMsg
        );

        SELECT v_JsonResult AS result;
        ROLLBACK;
    END;

    START TRANSACTION;

    -- 테이블의 총 레코드 수를 계산
    SELECT COUNT(*) INTO v_TotalCntOfEqp FROM tMstEqp;

    -- JSON 형식으로 결과 반환
    SET v_JsonResult = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_SenderController,
        'total_cnt_of_eqp', v_TotalCntOfEqp,
        'eqp_status', (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    CONCAT('No_', ROW_NUMBER() OVER (ORDER BY EqpGroupID, EqpSeqNo)), JSON_OBJECT(
                        'EqpGroupID', EqpGroupID,
                        'EqpSeqNo', EqpSeqNo,
                        'ProcessStatus', ProcessStatus,
                        'EqpStatus', EqpStatus
                    )
                )
            )
            FROM tMstEqp
        ),
        'error_msg', v_ErrorMsg
    );

    COMMIT;

    SELECT v_JsonResult AS result;
END $$
DELIMITER ;



-- 921. spLoadReqAtEquipment             장비에서 LoadReq event에 대한 처리
DELIMITER $$
CREATE PROCEDURE spLoadReqAtEquipment (
    IN p_InputJson JSON,
    OUT p_OutputJson JSON
)
BEGIN
    DECLARE v_EqpGroupID CHAR(1);
    DECLARE v_EqpSeqNo CHAR(1);
    DECLARE v_CurrentTime DATETIME;
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_SenderController VARCHAR(20) DEFAULT 'DB_Manager';
    DECLARE v_ErrorMsg VARCHAR(100) DEFAULT 'None';
    DECLARE v_JsonResult JSON;

    -- JSON 파라미터에서 값 추출
    SET v_EqpGroupID = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.EqpGroupID'));
    SET v_EqpSeqNo = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.EqpSeqNo'));

    -- 예외 처리 시작
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_StatusCode = MYSQL_ERRNO, 
            v_ErrorMsg = MESSAGE_TEXT;
        
        SET v_JsonResult = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_SenderController,
            'error_msg', v_ErrorMsg
        );

        SET p_OutputJson = v_JsonResult;
        ROLLBACK;
    END;

    START TRANSACTION;

    -- 현재 시간을 가져옴
    SET v_CurrentTime = NOW();

    -- tMstEqp 테이블의 ProcessStatus와 EventTime을 업데이트
    UPDATE tMstEqp
    SET ProcessStatus = 'LoadReq',
        EventTime = v_CurrentTime
    WHERE EqpGroupID = v_EqpGroupID
      AND EqpSeqNo = v_EqpSeqNo;

    COMMIT;

    -- JSON 형식으로 결과 반환
    SET v_JsonResult = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_SenderController,
        'error_msg', v_ErrorMsg
    );

    SET p_OutputJson = v_JsonResult;
END$$
DELIMITER ;


-- 922. spLoadCompAtEquipment            장비에서 LoadComp event에 대한 처리
DELIMITER $$
CREATE PROCEDURE spLoadCompAtEquipment (
    IN p_InputJson JSON,
    OUT p_OutputJson JSON
)
BEGIN
    DECLARE v_EqpGroupID CHAR(1);
    DECLARE v_EqpSeqNo CHAR(1);
    DECLARE v_CurrentTime DATETIME;
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_SenderController VARCHAR(20) DEFAULT 'DB_Manager';
    DECLARE v_ErrorMsg VARCHAR(100) DEFAULT 'None';
    DECLARE v_JsonResult JSON;

    -- JSON 파라미터에서 값 추출
    SET v_EqpGroupID = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.EqpGroupID'));
    SET v_EqpSeqNo = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.EqpSeqNo'));

    -- 예외 처리 시작
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_StatusCode = MYSQL_ERRNO, 
            v_ErrorMsg = MESSAGE_TEXT;
        
        SET v_JsonResult = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_SenderController,
            'error_msg', v_ErrorMsg
        );

        SET p_OutputJson = v_JsonResult;
        ROLLBACK;
    END;

    START TRANSACTION;

    -- 현재 시간을 가져옴
    SET v_CurrentTime = NOW();

    -- tMstEqp 테이블의 ProcessStatus와 EventTime을 업데이트
    UPDATE tMstEqp
    SET ProcessStatus = 'LoadComp',
        EventTime = v_CurrentTime
    WHERE EqpGroupID = v_EqpGroupID
      AND EqpSeqNo = v_EqpSeqNo;

    COMMIT;

    -- JSON 형식으로 결과 반환
    SET v_JsonResult = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_SenderController,
        'error_msg', v_ErrorMsg
    );

    SET p_OutputJson = v_JsonResult;
END$$
DELIMITER ;


-- 923. spUnloadReqAtEquipment           장비에서 UnloadReq event에 대한 처리
DELIMITER $$
CREATE PROCEDURE spUnloadReqAtEquipment (
    IN p_InputJson JSON,
    OUT p_OutputJson JSON
)
BEGIN
    DECLARE v_EqpGroupID CHAR(1);
    DECLARE v_EqpSeqNo CHAR(1);
    DECLARE v_CurrentTime DATETIME;
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_SenderController VARCHAR(20) DEFAULT 'DB_Manager';
    DECLARE v_ErrorMsg VARCHAR(100) DEFAULT 'None';
    DECLARE v_JsonResult JSON;

    -- JSON 파라미터에서 값 추출
    SET v_EqpGroupID = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.EqpGroupID'));
    SET v_EqpSeqNo = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.EqpSeqNo'));

    -- 예외 처리 시작
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_StatusCode = MYSQL_ERRNO, 
            v_ErrorMsg = MESSAGE_TEXT;
        
        SET v_JsonResult = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_SenderController,
            'error_msg', v_ErrorMsg
        );

        SET p_OutputJson = v_JsonResult;
        ROLLBACK;
    END;

    START TRANSACTION;

    -- 현재 시간을 가져옴
    SET v_CurrentTime = NOW();

    -- tMstEqp 테이블의 ProcessStatus와 EventTime을 업데이트
    UPDATE tMstEqp
    SET ProcessStatus = 'UnloadReq',
        EventTime = v_CurrentTime
    WHERE EqpGroupID = v_EqpGroupID
      AND EqpSeqNo = v_EqpSeqNo;

    COMMIT;

    -- JSON 형식으로 결과 반환
    SET v_JsonResult = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_SenderController,
        'error_msg', v_ErrorMsg
    );

    SET p_OutputJson = v_JsonResult;
END$$
DELIMITER ;


-- 924. spUnloadCompAtEquipment          장비에서 UnloadComp event에 대한 처리
DELIMITER $$
CREATE PROCEDURE spUnloadCompAtEquipment (
    IN p_InputJson JSON,
    OUT p_OutputJson JSON
)
BEGIN
    DECLARE v_EqpGroupID CHAR(1);
    DECLARE v_EqpSeqNo CHAR(1);
    DECLARE v_CurrentTime DATETIME;
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_SenderController VARCHAR(20) DEFAULT 'DB_Manager';
    DECLARE v_ErrorMsg VARCHAR(100) DEFAULT 'None';
    DECLARE v_JsonResult JSON;

    -- JSON 파라미터에서 값 추출
    SET v_EqpGroupID = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.EqpGroupID'));
    SET v_EqpSeqNo = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.EqpSeqNo'));

    -- 예외 처리 시작
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_StatusCode = MYSQL_ERRNO, 
            v_ErrorMsg = MESSAGE_TEXT;
        
        SET v_JsonResult = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_SenderController,
            'error_msg', v_ErrorMsg
        );

        SET p_OutputJson = v_JsonResult;
        ROLLBACK;
    END;

    START TRANSACTION;

    -- 현재 시간을 가져옴
    SET v_CurrentTime = NOW();

    -- tMstEqp 테이블의 ProcessStatus와 EventTime을 업데이트
    UPDATE tMstEqp
    SET ProcessStatus = 'UnloadComp',
        EventTime = v_CurrentTime
    WHERE EqpGroupID = v_EqpGroupID
      AND EqpSeqNo = v_EqpSeqNo;

    COMMIT;

    -- JSON 형식으로 결과 반환
    SET v_JsonResult = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_SenderController,
        'error_msg', v_ErrorMsg
    );

    SET p_OutputJson = v_JsonResult;
END$$
DELIMITER ;


-- 925. spLoadComp4BottleAtEquipment     Bottle에서 LoadComp event에 대한 처리
DELIMITER $$
CREATE PROCEDURE spLoadComp4BottleAtEquipment (
    IN p_InputJson JSON,
    OUT p_OutputJson JSON
)
BEGIN
    DECLARE v_BottleID CHAR(15);
    DECLARE v_CurrEqpGroupID CHAR(1);
    DECLARE v_CurrOperID CHAR(1);
    DECLARE v_CurrEqpSeqNo CHAR(1);
    DECLARE v_Position CHAR(4);
    DECLARE v_NextEqpGroupID CHAR(1);
    DECLARE v_NextOperID CHAR(1);
    DECLARE v_StartTime DATETIME;
    DECLARE v_CurrentTime DATETIME;
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_SenderController VARCHAR(20) DEFAULT 'DB_Manager';
    DECLARE v_ErrorMsg VARCHAR(100) DEFAULT 'None';
    DECLARE v_JsonResult JSON;
    DECLARE v_CurrentNextEqpGroupID CHAR(1);
    DECLARE v_CurrentNextOperID CHAR(1);

    -- JSON 파라미터에서 값 추출
    SET v_BottleID = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.BottleID'));
    SET v_CurrEqpGroupID = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.CurrEqpGroupID'));
    SET v_CurrOperID = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.CurrOperID'));
    SET v_CurrEqpSeqNo = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.CurrEqpSeqNo'));
    SET v_Position = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.Position'));

    -- 예외 처리 시작
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_StatusCode = MYSQL_ERRNO, 
            v_ErrorMsg = MESSAGE_TEXT;
        
        SET v_JsonResult = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_SenderController,
            'error_msg', v_ErrorMsg
        );

        SET p_OutputJson = v_JsonResult;
        ROLLBACK;
    END;

    START TRANSACTION;

    -- 현재 시간을 가져옴
    SET v_CurrentTime = NOW();

    -- tProcBottle 테이블에서 NextEqpGroupID와 NextOperID를 가져옴
    SELECT NextEqpGroupID, NextOperID
    INTO v_CurrentNextEqpGroupID, v_CurrentNextOperID
    FROM tProcBottle
    WHERE BottleID = v_BottleID
    LIMIT 1;

    -- input parameter의 CurrEqpGroupID가 NULL이면 v_CurrentNextEqpGroupID를 사용
    IF v_CurrEqpGroupID IS NULL THEN
        SET v_CurrEqpGroupID = v_CurrentNextEqpGroupID;
    END IF;

    -- input parameter의 CurrOperID가 NULL이면 v_CurrentNextOperID를 사용
    IF v_CurrOperID IS NULL THEN
        SET v_CurrOperID = v_CurrentNextOperID;
    END IF;

    -- input parameter의 CurrEqpSeqNo가 NULL이면 1을 사용
    IF v_CurrEqpSeqNo IS NULL THEN
        SET v_CurrEqpSeqNo = '1';
    END IF;

    -- input parameter의 Position이 NULL이면 '0001'을 사용
    IF v_Position IS NULL THEN
        SET v_Position = '0001';
    END IF;

    -- tMstRouteOper 테이블에서 NextEqpGroupID와 NextOperID를 가져옴
    SELECT NextEqpGroupID, NextOperID
    INTO v_NextEqpGroupID, v_NextOperID
    FROM tMstRouteOper
    WHERE CurrEqpGroupID = v_CurrEqpGroupID
      AND CurrOperID = v_CurrOperID
    LIMIT 1;

    -- tProcBottle 테이블의 CurrEqpGroupID, CurrOperID, CurrEqpSeqNo, Position, NextEqpGroupID, NextOperID, StartTime, EndTime 업데이트
    UPDATE tProcBottle
    SET CurrEqpGroupID = v_CurrEqpGroupID,
        CurrOperID = v_CurrOperID,
        CurrEqpSeqNo = v_CurrEqpSeqNo,
        Position = v_Position,
        NextEqpGroupID = v_NextEqpGroupID,
        NextOperID = v_NextOperID,
        StartTime = v_CurrentTime,
        EndTime = NULL
    WHERE BottleID = v_BottleID;        

    -- 조건에 따라 spTransferAndDeleteBottle 호출
    IF v_CurrEqpGroupID = '1' AND v_CurrOperID = '1' THEN
        CALL spTransferAndDeleteBottle(v_BottleID);
    END IF;

    COMMIT;

    -- JSON 형식으로 결과 반환
    SET v_JsonResult = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_SenderController,
        'current_next_eqp_group_id', v_CurrentNextEqpGroupID,
        'current_next_oper_id', v_CurrentNextOperID,
        'new_next_eqp_group_id', v_NextEqpGroupID,
        'new_next_oper_id', v_NextOperID,
        'error_msg', v_ErrorMsg
    );

    SET p_OutputJson = v_JsonResult;
END$$
DELIMITER ;


-- 926. spUnloadComp4BottleAtEquipment   Bottle에서 UnloadComp event에 대한 처리
DELIMITER $$
CREATE PROCEDURE spUnloadComp4BottleAtEquipment (
    IN p_InputJson JSON,
    OUT p_OutputJson JSON
)
BEGIN
    DECLARE v_BottleID CHAR(15);
    DECLARE v_CurrEqpGroupID CHAR(1);
    DECLARE v_CurrOperID CHAR(1);
    DECLARE v_NextEqpGroupID CHAR(1);
    DECLARE v_NextOperID CHAR(1);
    DECLARE v_DispatchingPriority TINYINT;
    DECLARE v_Position CHAR(4);
    DECLARE v_StartTime DATETIME;
    DECLARE v_CurrentTime DATETIME;
    DECLARE v_AdjStartTime DATETIME;
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_SenderController VARCHAR(20) DEFAULT 'DB_Manager';
    DECLARE v_ErrorMsg VARCHAR(100) DEFAULT 'None';
    DECLARE v_JsonResult JSON;

    -- JSON 파라미터에서 값 추출
    SET v_BottleID = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.BottleID'));
    SET v_CurrEqpGroupID = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.CurrEqpGroupID'));
    SET v_CurrOperID = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.CurrOperID'));

    -- 예외 처리 시작
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_StatusCode = MYSQL_ERRNO, 
            v_ErrorMsg = MESSAGE_TEXT;
        
        SET v_JsonResult = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_SenderController,
            'error_msg', v_ErrorMsg
        );

        SET p_OutputJson = v_JsonResult;
        ROLLBACK;
    END;

    START TRANSACTION;

    -- 현재 시간을 가져옴
    SET v_CurrentTime = NOW();
    SET v_AdjStartTime = DATE_SUB(v_CurrentTime, INTERVAL 60 SECOND);

    -- tProcBottle 테이블 EndTime 수정하고 tProcBotOper에 공정진행정보 insert
    IF v_CurrEqpGroupID = '1' AND v_CurrOperID = '1' THEN
        -- LoadComp Event 발생하지 않아 Next 공정정보를 수정해준다.
        -- Empty Bottle 반출을 Event 기준으로 함
        -- tProcBottle 테이블의 NextEqpGroupID, NextOperID, StartTime, EndTime 업데이트
        
        -- tMstRouteOper 테이블에서 NextEqpGroupID와 NextOperID를 가져옴
        SELECT NextEqpGroupID, NextOperID
        INTO v_NextEqpGroupID, v_NextOperID
        FROM tMstRouteOper
        WHERE CurrEqpGroupID = v_CurrEqpGroupID
          AND CurrOperID = v_CurrOperID
        LIMIT 1;

        UPDATE tProcBottle
        SET NextEqpGroupID = v_NextEqpGroupID,
            NextOperID = v_NextOperID,
            StartTime = IFNULL(StartTime, v_AdjStartTime),
            EndTime = v_CurrentTime
        WHERE BottleID = v_BottleID;
    ELSE
        -- tProcBottle 테이블의 EndTime을 업데이트
        UPDATE tProcBottle
        SET StartTime = IFNULL(StartTime, v_AdjStartTime),
            EndTime = v_CurrentTime
        WHERE BottleID = v_BottleID;
    END IF;

    -- tProcBottle 테이블에서 추가 정보를 가져옴
    SELECT DispatchingPriority, Position, StartTime
    INTO v_DispatchingPriority, v_Position, v_StartTime
    FROM tProcBottle
    WHERE BottleID = v_BottleID;

    INSERT INTO tProcBotOper (
        BottleID,
        EqpGroupID,
        OperID,
        StartTime,
        EndTime,
        DispatchingPriority,
        Position
    )
    VALUES (
        v_BottleID,
        v_CurrEqpGroupID,
        v_CurrOperID,
        v_StartTime,
        v_CurrentTime,
        v_DispatchingPriority,
        v_Position
    );

    COMMIT;

    -- JSON 형식으로 결과 반환
    SET v_JsonResult = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_SenderController,
        'error_msg', v_ErrorMsg
    );

    SET p_OutputJson = v_JsonResult;
END$$
DELIMITER ;


-- 931. spRequestBottleData              Bottle 관련 정보를 가져온다
-- GPT prompt
--     - tProcBottle table 데이터를 읽고 가져오는 저장 프로시저를 작성해줘.
--       입력파라메터는 json type BottleID이고 출력은 json type tProcBottle 데이터값으로 만들어줘.
--       maria db를 사용하고 있고, 예외 처리를 위한 DECLARE ... HANDLER 구문추가해줘.
DELIMITER $$
CREATE PROCEDURE spRequestBottleData (
    IN p_InputJson JSON,
    OUT p_OutputJson JSON
)
BEGIN
    DECLARE v_BottleID CHAR(15);
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_SenderController VARCHAR(20) DEFAULT 'DB_Manager';
    DECLARE v_ErrorMsg VARCHAR(100) DEFAULT 'None';
    DECLARE v_JsonResult JSON;
    DECLARE v_TotCountOfBottlePack INT;
    DECLARE v_JsonBottleInfo JSON;

    -- JSON 파라미터에서 값 추출
    SET v_BottleID = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.BottleID'));

    -- 예외 처리 시작
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_StatusCode = MYSQL_ERRNO, 
            v_ErrorMsg = MESSAGE_TEXT;
        
        SET v_JsonResult = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_SenderController,
            'error_msg', v_ErrorMsg
        );

        SET p_OutputJson = v_JsonResult;
        ROLLBACK;
    END;

    START TRANSACTION;

    -- tProcBottle 테이블의 데이터를 JSON 형식으로 변환하여 가져옴
    SELECT JSON_OBJECT(
        'BottleID', BottleID,
        'CurrEqpGroupID', CurrEqpGroupID,
        'CurrEqpSeqNo', CurrEqpSeqNo,
        'CurrOperID', CurrOperID,
        'NextEqpGroupID', NextEqpGroupID,
        'NextOperID', NextOperID,
        'ProjectNo', ProjectNo,
        'PackID', PackID,
        'AnalyzerCompletedTm', AnalyzerCompletedTm,
        'JudgeOfResearcher', JudgeOfResearcher,
        'ExperimentRequestName', ExperimentRequestName,
        'CurrLiquid', CurrLiquid,
        'RequestDate', RequestDate,
        'RequestTotCnt', RequestTotCnt,
        'RequestRealCnt', RequestRealCnt,
        'RequestSeqNo', RequestSeqNo,
        'MemberOfBottlePack', MemberOfBottlePack,
        'Position', Position,
        'StartTime', StartTime,
        'EndTime', EndTime,
        'DispatchingPriority', DispatchingPriority,
        'EventTime', EventTime,
        'PrevLiquid', PrevLiquid
    ) INTO v_JsonBottleInfo
    FROM tProcBottle
    WHERE BottleID = v_BottleID;

    COMMIT;

    -- JSON 형식으로 결과 반환
    SET v_JsonResult = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_SenderController,
        'bottle_info', v_JsonBottleInfo,
        'error_msg', v_ErrorMsg
    );

    SET p_OutputJson = v_JsonResult;
END$$
DELIMITER ;


-- 932. spRequestAllBottlesInfoFmEquipment       Bottle 관련 정보를 가져온다
DELIMITER $$
-- ReqBottleInfoFmEqp token event에 대한 처리
-- Bottle상태를 가져온다
-- 사용법
--    CALL spRequestAllBottlesInfoFmEquipment('1', '1');
-- RETURN
-- {
--    "status_code": 200,
--    "sender_controller": "DB_Manager",
--    "total_cnt_of_eqp": 70,
--    "eqp_status": [
--        {
--            "No_1": {
--                "BottleID": "Bot_001",
--                "ExperimentRequestName": "홍길동",
--                "CurrLiquid": "Acid",
--                "RequestDate": "2024-06-05",
--                "DispatchingPriority": 1,
--                "Position": "0110",
--                "EventTime": "2024-06-05"
--            }
--        },
--        {
--            "No_2": {
--                "BottleID": "Bot_002",
--                "ExperimentRequestName": "심봉사",
--                "CurrLiquid": "Base",
--                "RequestDate": "2024-06-06",
--                "DispatchingPriority": 9,
--                "Position": "0001",
--                "EventTime": "2024-06-05"
--            }
--        },
--        ...
--        {
--            "No_70": {
--                "BottleID": "Bot_090",
--                "ExperimentRequestName": "이몽룡",
--                "CurrLiquid": "Organic",
--                "RequestDate": "2024-06-07",
--                "DispatchingPriority": 5,
--                "Position": "0105",
--                "EventTime": "2024-06-05"
--            }
--        }
--    ],
--    "error_msg": "None"
-- }
DELIMITER $$
CREATE PROCEDURE spRequestAllBottlesInfoFmEquipment (
    IN p_InputJson JSON,
    OUT p_OutputJson JSON
)
BEGIN
    DECLARE v_EqpGroupID CHAR(1);
    DECLARE v_EqpSeqNo CHAR(1);
    DECLARE v_TotalCntOfEqp INT;
    DECLARE v_ErrorMsg NVARCHAR(100) DEFAULT 'None';
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_SenderController VARCHAR(20) DEFAULT 'DB_Manager';
    DECLARE v_JsonResult JSON;

    -- JSON 파라미터에서 값 추출
    SET v_EqpGroupID = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.EqpGroupID'));
    SET v_EqpSeqNo = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.EqpSeqNo'));

    -- 예외 처리 시작
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_StatusCode = MYSQL_ERRNO, 
            v_ErrorMsg = MESSAGE_TEXT;
        
        SET v_JsonResult = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_SenderController,
            'error_msg', v_ErrorMsg
        );

        SET p_OutputJson = v_JsonResult;
        ROLLBACK;
    END;

    START TRANSACTION;

    -- 테이블의 총 레코드 수를 계산
    SELECT COUNT(*) INTO v_TotalCntOfEqp 
    FROM tProcBottle 
    WHERE CurrEqpGroupID = v_EqpGroupID AND CurrEqpSeqNo = v_EqpSeqNo;

    -- JSON 형식으로 결과 반환
    SET v_JsonResult = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_SenderController,
        'total_cnt_of_eqp', v_TotalCntOfEqp,
        'eqp_status', (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    CONCAT('No_', ROW_NUMBER() OVER (ORDER BY BottleID)), JSON_OBJECT(
                        'BottleID', BottleID,
                        'ExperimentRequestName', ExperimentRequestName,
                        'CurrLiquid', CurrLiquid,
                        'RequestDate', DATE_FORMAT(RequestDate, '%Y-%m-%d'),
                        'DispatchingPriority', DispatchingPriority,
                        'Position', Position,
                        'EventTime', DATE_FORMAT(EventTime, '%Y-%m-%d')
                    )
                )
            )
            FROM tProcBottle
            WHERE CurrEqpGroupID = v_EqpGroupID 
              AND CurrEqpSeqNo = v_EqpSeqNo
            ORDER BY EventTime
        ),
        'error_msg', v_ErrorMsg
    );

    COMMIT;

    SET p_OutputJson = v_JsonResult;
END$$
DELIMITER ;


-- 933. spUpdateBottleStatus             Bottle상태를 임의적으로 수동 변경한다. 정보불일치 발생시 UI에서 사용.
-- ChangeBottleInfo token event에 대한 처리
-- Bottle상태를 변경한다
--
-- RETURN
-- {
--    "status_code": 200,
--    "sender_controller": "DB_Manager",
--    "error_msg": "None"
-- }
DELIMITER $$
CREATE PROCEDURE spUpdateBottleStatus (
    IN p_InputJson JSON,
    OUT p_OutputJson JSON
)
BEGIN
    DECLARE v_BottleID CHAR(15);
    DECLARE v_EqpGroupID CHAR(1);
    DECLARE v_EqpSeqNo CHAR(1);
    DECLARE v_OperID CHAR(1);
    DECLARE v_NextEqpGroupID CHAR(1);
    DECLARE v_NextOperID CHAR(1);
    DECLARE v_CurrentTime DATETIME;
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_SenderController VARCHAR(20) DEFAULT 'DB_Manager';
    DECLARE v_ErrorMsg VARCHAR(100) DEFAULT 'None';
    DECLARE v_JsonResult JSON;

    -- JSON 파라미터에서 값 추출
    SET v_BottleID = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.BottleID'));
    SET v_EqpGroupID = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.EqpGroupID'));
    SET v_EqpSeqNo = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.EqpSeqNo'));
    SET v_OperID = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.OperID'));
    SET v_NextEqpGroupID = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.NextEqpGroupID'));
    SET v_NextOperID = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.NextOperID'));

    -- 예외 처리 시작
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_StatusCode = MYSQL_ERRNO, 
            v_ErrorMsg = MESSAGE_TEXT;
        
        SET v_JsonResult = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_SenderController,
            'error_msg', v_ErrorMsg
        );

        SET p_OutputJson = v_JsonResult;
        ROLLBACK;
    END;

    START TRANSACTION;

    -- 현재 시간을 가져옴
    SET v_CurrentTime = NOW();

    -- tProcBottle 테이블의 레코드를 업데이트
    UPDATE tProcBottle
    SET CurrEqpGroupID = v_EqpGroupID,
        CurrEqpSeqNo = v_EqpSeqNo,
        CurrOperID = v_OperID,
        NextEqpGroupID = v_NextEqpGroupID,
        NextOperID = v_NextOperID,
        EventTime = v_CurrentTime
    WHERE BottleID = v_BottleID;

    COMMIT;

    -- JSON 형식으로 결과 반환
    SET v_JsonResult = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_SenderController,
        'error_msg', v_ErrorMsg
    );

    SET p_OutputJson = v_JsonResult;
END$$
DELIMITER ;


-- 934. spRetrieveAllBottleStatuses      모든 Bottle상태를 가져온다
-- ReqAllBottlesInfo token event에 대한 처리
-- 모든 Bottle상태를 가져온다
--
-- RETURN
-- {
--    "status_code": 200,
--    "sender_controller": "DB_Manager",
--    "total_cnt_of_eqp": 300,
--    "eqp_status": [
--        {
--            "No_1": {
--                "BottleID": "Bot_001",
--                "EqpGroupID": "1",
--                "EqpSeqNo": "1",
--                "ExperimentRequestName": "홍길동",
--                "CurrLiquid": "Acid",
--                "RequestDate": "2024-06-05",
--                "DispatchingPriority": 1,
--                "Position": "0110",
--                "EventTime": "2024-06-05"
--            }
--        },
--        {
--            "No_2": {
--                "BottleID": "Bot_002",
--                "EqpGroupID": "1",
--                "EqpSeqNo": "1",
--                "ExperimentRequestName": "심봉사",
--                "CurrLiquid": "Base",
--                "RequestDate": "2024-06-06",
--                "DispatchingPriority": 9,
--                "Position": "0001",
--                "EventTime": "2024-06-05"
--            }
--        },
--        ...
--        {
--            "No_300": {
--                "BottleID": "Bot_090",
--                "EqpGroupID": "5",
--                "EqpSeqNo": "1",
--                "ExperimentRequestName": "이몽룡",
--                "CurrLiquid": "Organic",
--                "RequestDate": "2024-06-07",
--                "DispatchingPriority": 5,
--                "Position": "0105",
--                "EventTime": "2024-06-05"
--            }
--        }
--    ],
--    "error_msg": "None"
-- }
DELIMITER $$
CREATE PROCEDURE spRetrieveAllBottleStatuses()
BEGIN
    DECLARE v_TotalCntOfEqp INT;
    DECLARE v_ErrorMsg NVARCHAR(100) DEFAULT 'None';
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_SenderController VARCHAR(20) DEFAULT 'DB_Manager';
    DECLARE v_JsonResult JSON;

    -- 예외 처리 시작
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_StatusCode = MYSQL_ERRNO, 
            v_ErrorMsg = MESSAGE_TEXT;
        
        SET v_JsonResult = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_SenderController,
            'error_msg', v_ErrorMsg
        );

        SELECT v_JsonResult AS result;
        ROLLBACK;
    END;

    START TRANSACTION;

    -- 테이블의 총 레코드 수를 계산
    SELECT COUNT(*) INTO v_TotalCntOfEqp 
    FROM tProcBottle;

    -- JSON 형식으로 결과 반환
    SET v_JsonResult = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_SenderController,
        'total_cnt_of_eqp', v_TotalCntOfEqp,
        'eqp_status', (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    CONCAT('No_', ROW_NUMBER() OVER (ORDER BY CurrEqpGroupID, CurrEqpSeqNo)), JSON_OBJECT(
                        'BottleID', BottleID,
                        'EqpGroupID', CurrEqpGroupID,
                        'EqpSeqNo', CurrEqpSeqNo,
                        'ExperimentRequestName', ExperimentRequestName,
                        'CurrLiquid', CurrLiquid,
                        'RequestDate', DATE_FORMAT(RequestDate, '%Y-%m-%d'),
                        'DispatchingPriority', DispatchingPriority,
                        'Position', Position,
                        'EventTime', DATE_FORMAT(EventTime, '%Y-%m-%d')
                    )
                )
            )
            FROM tProcBottle
            ORDER BY CurrEqpGroupID, CurrEqpSeqNo
        ),
        'error_msg', v_ErrorMsg
    );

    COMMIT;

    SELECT v_JsonResult AS result;
END $$
DELIMITER ;


-- 935. spRetrievePendingBottles         투입대기중인 Bottle정보를 가져온다
-- InputWaitingBottleInfoFmEqp token event에 대한 처리
-- 투입대기중인 Bottle정보를 가져온다
--
-- RETURN
-- {
--    "status_code": 200,
--    "sender_controller": "DB_Manager",
--    "total_cnt_of_eqp": 5,
--    "eqp_status": [
--        {
--            "No_1": {
--                "BottleID": "Bot_001",
--                "ExperimentRequestName": "홍길동",
--                "CurrLiquid": "Acid",
--                "RequestDate": "2024-06-05",
--                "DispatchingPriority": 1,
--                "Position": "0110",
--                "EventTime": "2024-06-05"
--            }
--        },
--        {
--            "No_2": {
--                "BottleID": "Bot_002",
--                "ExperimentRequestName": "심봉사",
--                "CurrLiquid": "Base",
--                "RequestDate": "2024-06-06",
--                "DispatchingPriority": 9,
--                "Position": "0001",
--                "EventTime": "2024-06-05"
--            }
--        },
--        ...
--        {
--            "No_5": {
--                "BottleID": "Bot_090",
--                "ExperimentRequestName": "이몽룡",
--                "CurrLiquid": "Organic",
--                "RequestDate": "2024-06-07",
--                "DispatchingPriority": 5,
--                "Position": "0105",
--                "EventTime": "2024-06-05"
--            }
--        }
--    ],
--    "error_msg": "None"
-- }
DELIMITER $$
CREATE PROCEDURE spRetrievePendingBottles (
    IN p_InputJson JSON,
    OUT p_OutputJson JSON
)
BEGIN
    DECLARE v_NextEqpGroupID CHAR(1);
    DECLARE v_NextOperID CHAR(1);
    DECLARE v_TotalCntOfEqp INT;
    DECLARE v_ErrorMsg NVARCHAR(100) DEFAULT 'None';
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_SenderController VARCHAR(20) DEFAULT 'DB_Manager';
    DECLARE v_JsonResult JSON;

    -- JSON 파라미터에서 값 추출
    SET v_NextEqpGroupID = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.NextEqpGroupID'));
    SET v_NextOperID = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.NextOperID'));

    -- 예외 처리 시작
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_StatusCode = MYSQL_ERRNO, 
            v_ErrorMsg = MESSAGE_TEXT;
        
        SET v_JsonResult = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_SenderController,
            'error_msg', v_ErrorMsg
        );

        SET p_OutputJson = v_JsonResult;
        ROLLBACK;
    END;

    START TRANSACTION;

    -- 테이블의 총 레코드 수를 계산
    SELECT COUNT(*) INTO v_TotalCntOfEqp 
    FROM tProcBottle 
    WHERE NextEqpGroupID = v_NextEqpGroupID AND NextOperID = v_NextOperID;

    -- JSON 형식으로 결과 반환
    SET v_JsonResult = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_SenderController,
        'total_cnt_of_eqp', v_TotalCntOfEqp,
        'eqp_status', (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    CONCAT('No_', ROW_NUMBER() OVER (ORDER BY BottleID)), JSON_OBJECT(
                        'BottleID', BottleID,
                        'ExperimentRequestName', ExperimentRequestName,
                        'CurrLiquid', CurrLiquid,
                        'RequestDate', DATE_FORMAT(RequestDate, '%Y-%m-%d'),
                        'DispatchingPriority', DispatchingPriority,
                        'Position', Position,
                        'EventTime', DATE_FORMAT(EventTime, '%Y-%m-%d')
                    )
                )
            )
            FROM tProcBottle
            WHERE NextEqpGroupID = v_NextEqpGroupID AND NextOperID = v_NextOperID
            ORDER BY BottleID
        ),
        'error_msg', v_ErrorMsg
    );

    COMMIT;

    SET p_OutputJson = v_JsonResult;
END$$
DELIMITER ;


-- 936. spRetrieveEmptyBottleCount       설비에서 대기중인 Bottle수량정보를 가져온다
-- GetCountEmptyBottleAtInOutBottle token event에 대한 처리
-- 설비에서 대기중인 Bottle수량정보를 가져온다
--
-- RETURN
-- {
--    "status_code": 200,
--    "sender_controller": "DB_Manager",
--    "total_cnt_of_empty_bottle": 10,
--    "error_msg": "None"
-- }
DELIMITER $$
CREATE PROCEDURE spRetrieveEmptyBottleCount (
    IN p_InputJson JSON,
    OUT p_OutputJson JSON
)
BEGIN
    DECLARE v_CurrEqpGroupID CHAR(1);
    DECLARE v_CurrEqpSeqNo CHAR(1);
    DECLARE v_TotalCntOfEmptyBottle INT;
    DECLARE v_ErrorMsg NVARCHAR(100) DEFAULT 'None';
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_SenderController VARCHAR(20) DEFAULT 'DB_Manager';
    DECLARE v_JsonResult JSON;

    -- JSON 파라미터에서 값 추출
    SET v_CurrEqpGroupID = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.CurrEqpGroupID'));
    SET v_CurrEqpSeqNo = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.CurrEqpSeqNo'));

    -- 예외 처리 시작
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_StatusCode = MYSQL_ERRNO, 
            v_ErrorMsg = MESSAGE_TEXT;
        
        SET v_JsonResult = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_SenderController,
            'error_msg', v_ErrorMsg
        );

        SET p_OutputJson = v_JsonResult;
        ROLLBACK;
    END;

    START TRANSACTION;

    -- 테이블의 총 빈 병 레코드 수를 계산
    SELECT COUNT(*) INTO v_TotalCntOfEmptyBottle 
    FROM tProcBottle 
    WHERE CurrEqpGroupID = v_CurrEqpGroupID 
      AND CurrEqpSeqNo = v_CurrEqpSeqNo;

    COMMIT;

    -- JSON 형식으로 결과 반환
    SET v_JsonResult = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_SenderController,
        'total_cnt_of_empty_bottle', v_TotalCntOfEmptyBottle,
        'error_msg', v_ErrorMsg
    );

    SET p_OutputJson = v_JsonResult;
END$$
DELIMITER ;


-- 937. spFetchBottleProcessHistory      Bottle에서 수행한 공정이력정보를 가져온다
-- Req4BottleProcessHistory token event에 대한 처리
-- Bottle에서 수행한 공정이력정보를 가져온다
-- RETURN
-- {
--    "status_code": 200,
--    "sender_controller": "DB_Manager",
--    "total_cnt_of_process": 5,
--    "process_of_bottle": [
--        {
--            "No_1": {
--                "EqpGroupID": "1",
--                "OperID": "2",
--                "StartTime": "2024-06-05",
--                "EndTime": "2024-06-05",
--                "DispatchingPriority": 1,
--                "Position": "0110"
--            }
--        },
--        {
--            "No_2": {
--                "EqpGroupID": "2",
--                "OperID": "1",
--                "StartTime": "2024-06-06",
--                "EndTime": "2024-06-05",
--                "DispatchingPriority": 9,
--                "Position": "0001"
--            }
--        },
--        ...
--        {
--            "No_5": {
--                "EqpGroupID": "5",
--                "OperID": "1",
--                "StartTime": "2024-06-07",
--                "EndTime": "2024-06-05",
--                "DispatchingPriority": 5,
--                "Position": "0105"
--            }
--        }
--    ],
--    "error_msg": "None"
-- }
DELIMITER $$
CREATE PROCEDURE spFetchBottleProcessHistory (
    IN p_InputJson JSON,
    OUT p_OutputJson JSON
)
BEGIN
    DECLARE v_BottleID CHAR(15);
    DECLARE v_TotalCntOfProcess INT;
    DECLARE v_ErrorMsg NVARCHAR(100) DEFAULT 'None';
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_SenderController VARCHAR(20) DEFAULT 'DB_Manager';
    DECLARE v_JsonResult JSON;

    -- JSON 파라미터에서 값 추출
    SET v_BottleID = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.BottleID'));

    -- 예외 처리 시작
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_StatusCode = MYSQL_ERRNO, 
            v_ErrorMsg = MESSAGE_TEXT;
        
        SET v_JsonResult = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_SenderController,
            'error_msg', v_ErrorMsg
        );

        SET p_OutputJson = v_JsonResult;
        ROLLBACK;
    END;

    START TRANSACTION;

    -- 테이블의 총 프로세스 레코드 수를 계산
    SELECT COUNT(*) INTO v_TotalCntOfProcess 
    FROM tProcBotOper 
    WHERE BottleID = v_BottleID;

    -- JSON 형식으로 결과 반환
    SET v_JsonResult = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_SenderController,
        'total_cnt_of_process', v_TotalCntOfProcess,
        'process_of_bottle', (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    CONCAT('No_', ROW_NUMBER() OVER (ORDER BY EqpGroupID, OperID)), JSON_OBJECT(
                        'BottleID', BottleID,
                        'EqpGroupID', EqpGroupID,
                        'OperID', OperID,
                        'StartTime', DATE_FORMAT(StartTime, '%Y-%m-%d'),
                        'EndTime', DATE_FORMAT(EndTime, '%Y-%m-%d'),
                        'DispatchingPriority', DispatchingPriority,
                        'Position', Position
                    )
                )
            )
            FROM tProcBotOper
            WHERE BottleID = v_BottleID
            ORDER BY EqpGroupID, OperID
        ),
        'error_msg', v_ErrorMsg
    );

    COMMIT;

    SET p_OutputJson = v_JsonResult;
END$$
DELIMITER ;





-- 9A1. spTransferAndDeleteBottle        Bottle 재사용을 위하여 데이터를 Hist로 이동하고 기존 데이터는 삭제한다.
DELIMITER $$
CREATE PROCEDURE spTransferAndDeleteBottle (
    IN p_BottleID CHAR(15)
)
BEGIN
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_ErrorMsg VARCHAR(100) DEFAULT 'None';
    DECLARE v_JsonResult JSON;

    -- 예외 처리 시작
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_StatusCode = MYSQL_ERRNO, 
            v_ErrorMsg = MESSAGE_TEXT;
        
        SET v_JsonResult = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_SenderController,
            'error_msg', v_ErrorMsg
        );

        SELECT v_JsonResult AS result;
        ROLLBACK;
    END;

    START TRANSACTION;

    -- tHisProcBotOper 테이블에 tProcBotOper 테이블의 데이터를 삽입
    INSERT INTO tHisProcBotOper (
        BottleID,
        EqpGroupID,
        OperID,
        StartTime,
        EndTime,
        DispatchingPriority,
        Position
    )
    SELECT 
        BottleID,
        CurrEqpGroupID AS EqpGroupID,
        CurrOperID AS OperID,
        StartTime,
        EndTime,
        DispatchingPriority,
        Position
    FROM tProcBotOper
    WHERE BottleID = p_BottleID;

    -- tProcBotOper 테이블에서 해당 BottleID의 데이터를 삭제
    DELETE FROM tProcBotOper
    WHERE BottleID = p_BottleID;

    COMMIT;

    -- JSON 형식으로 결과 반환
    SET v_JsonResult = JSON_OBJECT(
        'status_code', v_StatusCode,
        'error_msg', v_ErrorMsg
    );

    SELECT v_JsonResult AS result;
END$$
DELIMITER ;


-- 9A2. spFetchNextOperationFromRoute    차기 공정정보를 가져온다
DELIMITER $$
-- 차기 공정정보를 가져온다
-- 사용법
--    1. 세션 변수 선언
--       SET @NextEqpGroupID = '';
--       SET @NextOperID = '';
--    2. 저장 프로시저 호출
--       CALL spFetchNextOperationFromRoute('1', '1', @NextEqpGroupID, @NextOperID);
--    3. 결과 확인
--       SELECT @NextEqpGroupID AS NextEqpGroupID, @NextOperID AS NextOperID;
DELIMITER $$
CREATE PROCEDURE spFetchNextOperationFromRoute (
    IN p_InputJson JSON,
    OUT p_OutputJson JSON
)
BEGIN
    DECLARE v_CurrEqpGroupID CHAR(1);
    DECLARE v_CurrOperID CHAR(1);
    DECLARE v_NextEqpGroupID CHAR(1);
    DECLARE v_NextOperID CHAR(1);
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_ErrorMsg VARCHAR(255) DEFAULT 'None';
    DECLARE v_JsonResult JSON;

    -- 예외 처리 시작
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_StatusCode = MYSQL_ERRNO, 
            v_ErrorMsg = MESSAGE_TEXT;
        
        SET v_JsonResult = JSON_OBJECT(
            'status_code', v_StatusCode,
            'error_msg', v_ErrorMsg
        );

        SET p_OutputJson = v_JsonResult;
        ROLLBACK;
    END;

    START TRANSACTION;

    -- JSON 파라미터에서 값 추출
    SET v_CurrEqpGroupID = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.CurrEqpGroupID'));
    SET v_CurrOperID = JSON_UNQUOTE(JSON_EXTRACT(p_InputJson, '$.CurrOperID'));

    -- 다음 작업 정보를 조회
    SELECT NextEqpGroupID, NextOperID
    INTO v_NextEqpGroupID, v_NextOperID
    FROM tMstRouteOper
    WHERE CurrEqpGroupID = v_CurrEqpGroupID
      AND CurrOperID = v_CurrOperID
    LIMIT 1;

    -- JSON 형식으로 결과 반환
    SET v_JsonResult = JSON_OBJECT(
        'status_code', v_StatusCode,
        'NextEqpGroupID', v_NextEqpGroupID,
        'NextOperID', v_NextOperID,
        'error_msg', v_ErrorMsg
    );

    SET p_OutputJson = v_JsonResult;

    COMMIT;
END$$
DELIMITER ;


-- 9A3. spUpdateNextOperation            현재공정완료했을때 차기 공정정보 Set한다.
-- 현재공정완료했을때 차기 공정정보 Set한다.
DELIMITER $$
CREATE PROCEDURE spUpdateNextOperation (
    IN p_BottleID CHAR(1),
    IN p_CurrEqpGroupID CHAR(1),
    IN p_CurrOperID CHAR(1)
)
BEGIN
    DECLARE v_NextEqpGroupID CHAR(1);
    DECLARE v_NextOperID CHAR(1);

    -- tMstRouteOper 테이블에서 NextEqpGroupID와 NextOperID를 가져옴
    SELECT NextEqpGroupID, NextOperID
    INTO v_NextEqpGroupID, v_NextOperID
    FROM tMstRouteOper
    WHERE CurrEqpGroupID = p_CurrEqpGroupID
      AND CurrOperID = p_CurrOperID
    LIMIT 1;

    -- tProcBottle 테이블의 NextEqpGroupID와 NextOperID를 업데이트
    UPDATE tProcBottle
    SET NextEqpGroupID = v_NextEqpGroupID,
        NextOperID = v_NextOperID
    WHERE BottleID = p_BottleID
      AND CurrEqpGroupID = p_CurrEqpGroupID
      AND CurrOperID = p_CurrOperID;
END $$
DELIMITER ;


-- 9B1.  UpdateNextOper_Insert           LoadComp, UnloadComp에 대한 처리
-- 사용안함
-- ProcessLoadUnloadCompletion 통합됨
DELIMITER $$
CREATE PROCEDURE UpdateNextOper_Insert (
    IN p_BottleID CHAR(15),
    IN p_CurrEqpGroupID CHAR(1),
    IN p_CurrOperID CHAR(1),
    IN p_CompType VARCHAR(10)  -- "LoadComp" 또는 "UnloadComp" 값을 입력받는 매개변수
)
BEGIN
    DECLARE v_NextEqpGroupID CHAR(1);
    DECLARE v_NextOperID CHAR(1);
    DECLARE v_DispatchingPriority TINYINT;
    DECLARE v_Position CHAR(4);
    DECLARE v_StartTime DATETIME;
    DECLARE v_CurrentTime DATETIME;

    -- 현재 시간을 가져옴
    SET v_CurrentTime = NOW();

    -- tMstRouteOper 테이블에서 NextEqpGroupID와 NextOperID를 가져옴
    SELECT NextEqpGroupID, NextOperID
    INTO v_NextEqpGroupID, v_NextOperID
    FROM tMstRouteOper
    WHERE CurrEqpGroupID = p_CurrEqpGroupID
      AND CurrOperID = p_CurrOperID
    LIMIT 1;

    -- tProcBottle 테이블의 NextEqpGroupID, NextOperID, StartTime 또는 EndTime을 업데이트
    UPDATE tProcBottle
    SET NextEqpGroupID = v_NextEqpGroupID,
        NextOperID = v_NextOperID,
        StartTime = IF(p_CompType = 'LoadComp', v_CurrentTime, StartTime),
        EndTime = IF(p_CompType = 'UnloadComp', v_CurrentTime, EndTime)
    WHERE BottleID = p_BottleID
      AND CurrEqpGroupID = p_CurrEqpGroupID
      AND CurrOperID = p_CurrOperID;

    -- tProcBottle 테이블에서 추가 정보를 가져옴
    SELECT DispatchingPriority, Position, StartTime
    INTO v_DispatchingPriority, v_Position, v_StartTime
    FROM tProcBottle
    WHERE BottleID = p_BottleID;

    -- p_CompType이 'UnloadComp'일 때만 tProcBotOper 테이블에 레코드 삽입
    IF p_CompType = 'UnloadComp' THEN
        INSERT INTO tProcBotOper (
            BottleID,
            EqpGroupID,
            OperID,
            StartTime,
            EndTime,
            DispatchingPriority,
            Position
        )
        VALUES (
            p_BottleID,
            p_CurrEqpGroupID,
            v_NextOperID,
            v_StartTime,
            v_CurrentTime,
            v_DispatchingPriority,
            v_Position
        );
    END IF;

END $$
DELIMITER ;


-- 9B2.  ProcessLoadUnloadCompletion     세정후 Bottle 재사용을 위해 분석실 내부 Load Port에 반출입기에 입고될때 기존 Data 삭제하고 History 이동한다
-- 사용안함. LoadComp, UnloadComp 분리해서 처리
-- LoadComp, UnloadComp token event에 대한 처리
-- LoadComp, UnloadComp Token 수신시 호출
-- 세정후 Bottle 재사용을 위해 분석실 내부 Load Port에 반출입기에 입고될때 기존 Data 삭제하고 History 이동한다

-- 사용법
--    CALL ProcessLoadUnloadCompletion('A123456789012345', '1', '1', 'LoadComp');  
--    예시: BottleID 'A123456789012345', CurrEqpID '1', CurrOperID '1', CompType 'LoadComp'
-- RETURN
-- {
--    "status_code": 200,
--    "sender_controller": "DB_Manager",
--    "error_msg": "None"
-- }
DELIMITER $$
CREATE PROCEDURE ProcessLoadUnloadCompletion (
    IN p_BottleID CHAR(15),
    IN p_CurrEqpGroupID CHAR(1),
    IN p_CurrOperID CHAR(1),
    IN p_CompType VARCHAR(10)  -- "LoadComp" 또는 "UnloadComp" 값을 입력받는 매개변수
)
BEGIN
    DECLARE v_NextEqpGroupID CHAR(1);
    DECLARE v_NextOperID CHAR(1);
    DECLARE v_DispatchingPriority TINYINT;
    DECLARE v_Position CHAR(4);
    DECLARE v_StartTime DATETIME;
    DECLARE v_CurrentTime DATETIME;
    DECLARE v_AdjStartTime DATETIME;
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_SenderController VARCHAR(20) DEFAULT 'DB_Manager';
    DECLARE v_ErrorMsg VARCHAR(100) DEFAULT 'None';
    DECLARE v_JsonResult JSON;

    -- 예외 처리 시작
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_StatusCode = MYSQL_ERRNO, 
            v_ErrorMsg = MESSAGE_TEXT;
        
        SET v_JsonResult = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_SenderController,
            'error_msg', v_ErrorMsg
        );

        SELECT v_JsonResult AS result;
        ROLLBACK;
    END;

    START TRANSACTION;

    -- 현재 시간을 가져옴
    SET v_CurrentTime = NOW();
    SET v_AdjStartTime = DATE_SUB(v_CurrentTime, INTERVAL 60 SECOND);

    -- tMstRouteOper 테이블에서 NextEqpGroupID와 NextOperID를 가져옴
    SELECT NextEqpGroupID, NextOperID
    INTO v_NextEqpGroupID, v_NextOperID
    FROM tMstRouteOper
    WHERE CurrEqpGroupID = p_CurrEqpGroupID
      AND CurrOperID = p_CurrOperID
    LIMIT 1;

    IF p_CompType = 'LoadComp' THEN
        -- tProcBottle 테이블 StartTime, Next 공정정보 수정
        IF p_CurrEqpGroupID = '1' AND p_CurrOperID = '5' THEN
            -- p_CurrOperID가 '5'일 때 tProcBotOper 정보를 tHisProcBotOper로 이동하고 
            -- tProcBotOper의 bottle 정보를 삭제
            INSERT INTO tHisProcBotOper (
                BottleID,
                EqpGroupID,
                OperID,
                StartTime,
                EndTime,
                DispatchingPriority,
                Position
            )
            SELECT 
                BottleID,
                EqpGroupID,
                OperID,
                StartTime,
                EndTime,
                DispatchingPriority,
                Position
            FROM tProcBotOper
            WHERE BottleID = p_BottleID;

            -- tProcBotOper의 기존 bottle 정보 삭제
            DELETE FROM tProcBotOper
            WHERE BottleID = p_BottleID;
        ELSE
            -- tProcBottle 테이블의 NextEqpGroupID, NextOperID, StartTime 업데이트
            UPDATE tProcBottle
            SET NextEqpGroupID = v_NextEqpGroupID,
                NextOperID = v_NextOperID,
                StartTime = v_CurrentTime
            WHERE BottleID = p_BottleID;        
        END IF;

    ELSIF p_CompType = 'UnloadComp' THEN
        -- tProcBottle 테이블 EndTime 수정하고 tProcBotOper에 공정진행정보 insert
        IF p_CurrEqpGroupID = '1' AND p_CurrOperID = '1' THEN
            -- LoadComp Event 발생하지 않아 Next 공정정보를 수정해준다.
            -- Empty Bottle 반출을 Event 기준으로 함
            -- tProcBottle 테이블의 NextEqpGroupID, NextOperID, StartTime, EndTime 업데이트
            UPDATE tProcBottle
            SET NextEqpGroupID = v_NextEqpGroupID,
                NextOperID = v_NextOperID,
                StartTime = IFNULL(StartTime, v_AdjStartTime),
                EndTime = v_CurrentTime
            WHERE BottleID = p_BottleID;
        ELSE
            -- tProcBottle 테이블의 EndTime을 업데이트
            UPDATE tProcBottle
            SET StartTime = IFNULL(StartTime, v_AdjStartTime),
                EndTime = v_CurrentTime
            WHERE BottleID = p_BottleID;
        END IF;
        
        -- tProcBottle 테이블에서 추가 정보를 가져옴
        SELECT DispatchingPriority, Position, StartTime
        INTO v_DispatchingPriority, v_Position, v_StartTime
        FROM tProcBottle
        WHERE BottleID = p_BottleID;

        INSERT INTO tProcBotOper (
            BottleID,
            EqpGroupID,
            OperID,
            StartTime,
            EndTime,
            DispatchingPriority,
            Position
        )
        VALUES (
            p_BottleID,
            p_CurrEqpGroupID,
            p_CurrOperID,
            v_StartTime,
            v_CurrentTime,
            v_DispatchingPriority,
            v_Position
        );
    END IF;

    COMMIT;

    -- JSON 형식으로 결과 반환
    SET v_JsonResult = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_SenderController,
        'error_msg', v_ErrorMsg
    );

    SELECT v_JsonResult AS result;
END $$
DELIMITER ;


-- 9B3.  RetrieveSuitableBottleAtStocker Stocker에서 Bottle 정보를 가져온다
-- 현재 사용하지 않음.
-- spExtractSuitableBottlePackCountAtStocker, spGetBottleInfoByPackID 분리해서 처리하는 방식으로 변경됨
-- RETURN
-- {
--    "status_code": 200,
--    "sender_controller": "DB_Manager",
--    "TotCountOfBottlePack" : 5,
--    "BottleInfo" : [
--      { 
--          "BottleID_1" : "ID_001",
--          "Position_1" : "1021"
--      },
--      { 
--          "BottleID_2" : "ID_002",
--          "Position_2" : "1022"
--      },
--      ...
--      { 
--          "BottleID_5" : "ID_005",
--          "Position_5" : "1025"
--      }
--   ],    
--    "error_msg": "None"
-- }
DELIMITER //
CREATE PROCEDURE RetrieveSuitableBottleAtStocker()
BEGIN
    DECLARE TotCountOfBottlePack INT;
    DECLARE Zone NVARCHAR(10);
    DECLARE SelectedPosition CHAR(1);
    DECLARE SelectedBottleID CHAR(15);
    DECLARE SelectedRequestDate DATETIME;

    -- Declare variables for error handling
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_ErrorMsg TEXT DEFAULT 'None';
    DECLARE v_SenderController VARCHAR(20) DEFAULT 'DB_Manager';
    DECLARE v_JsonResult JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_StatusCode = MYSQL_ERRNO, 
            v_ErrorMsg = MESSAGE_TEXT;
        
        SET v_JsonResult = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_SenderController,
            'error_msg', v_ErrorMsg
        );

        SELECT v_JsonResult AS result;
        ROLLBACK;
    END;

    START TRANSACTION;

    -- Get the first position, BottleID, total count of bottles in a pack, and RequestDate to determine the Zone
    SELECT 
        LEFT(Position, 1), 
        BottleID,
        RequestTotCnt,
        RequestDate
    INTO
        SelectedPosition,
        SelectedBottleID,
        TotCountOfBottlePack,
        SelectedRequestDate
    FROM tProcBottle
    ORDER BY DispatchingPriority DESC, RequestDate
    LIMIT 1;

    IF SelectedPosition = '1' THEN
        SET Zone = 'Left';
    ELSEIF SelectedPosition = '2' THEN
        SET Zone = 'Right';
    ELSE
        SET Zone = 'NotFound';
    END IF;

    -- Select the results in the required JSON format
    SET v_JsonResult = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_SenderController,
        'TotCountOfBottlePack', TotCountOfBottlePack,
        'Zone', Zone,
        'BottleInfo', (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'BottleID', BottleID,
                    'Position', Position
                )
            )
            FROM (
                SELECT BottleID, Position
                FROM tProcBottle
                WHERE RequestDate = SelectedRequestDate
            ) AS BottleDetails
        ),
        'error_msg', v_ErrorMsg
    );

    SELECT v_JsonResult AS result;

    COMMIT;
END //
DELIMITER ;


-- 9B4.  UpdateEqpProcessStatus          장비의 Process상태를 변경한다. (LoadReq, LoadComp, UnLoadReq, UnLoadComp)
-- 사용안함. LoadReq, LoadComp, UnLoadReq, UnLoadComp stored procedure 분리처리
-- LoadRequest, UnloadRequest, ReserveEqpPort4Dispatch token event에 대한 처리
-- 장비의 Process상태를 변경한다. (LoadReq, UnLoadReq, Idle, Pause, Reserve)
-- Dispatcher가 반송이 가능한 상태인지 확인하기 위해 필요
--
-- 사용법
--    CALL UpdateEqpProcessStatus('1', '1', 'LoadComp');
-- RETURN
-- {
--    "status_code": 200,
--    "sender_controller": "DB_Manager",
--    "error_msg": "None"
-- }
DELIMITER $$
CREATE PROCEDURE UpdateEqpProcessStatus (
    IN p_EqpGroupID CHAR(1),
    IN p_EqpSeqNo CHAR(1),
    IN p_NewProcessStatus NVARCHAR(12)
)
BEGIN
    DECLARE v_CurrentTime DATETIME;
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_SenderController VARCHAR(20) DEFAULT 'DB_Manager';
    DECLARE v_ErrorMsg VARCHAR(100) DEFAULT 'None';
    DECLARE v_JsonResult JSON;

    -- 예외 처리 시작
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_StatusCode = MYSQL_ERRNO, 
            v_ErrorMsg = MESSAGE_TEXT;
        
        SET v_JsonResult = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_SenderController,
            'error_msg', v_ErrorMsg
        );

        SELECT v_JsonResult AS result;
        ROLLBACK;
    END;

    START TRANSACTION;

    -- 현재 시간을 가져옴
    SET v_CurrentTime = NOW();

    -- tMstEqp 테이블의 ProcessStatus와 EventTime을 업데이트
    UPDATE tMstEqp
    SET ProcessStatus = p_NewProcessStatus,
        EventTime = v_CurrentTime
    WHERE EqpGroupID = p_EqpGroupID
      AND EqpSeqNo = p_EqpSeqNo;

    COMMIT;

    -- JSON 형식으로 결과 반환
    SET v_JsonResult = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_SenderController,
        'error_msg', v_ErrorMsg
    );

    SELECT v_JsonResult AS result;
END $$
DELIMITER ;


-- 9B5. GetTopPriorityBottle             stocker내에 bottle 우선순위, 입고순서로 sotting하여 해당 bottle 정보 출력
-- stocker내에 bottle 우선순위, 입고순서로 sotting하여 해당 bottle 정보 출력
-- 사용법
--    CALL GetTopPriorityBottle('3', '1', '2', '1');
-- RETURN
--    정상적으로 병 정보를 조회한 경우
--    {
--      "status_code": 200,
--      "sender_controller": "DB_Manager",
--      "top_priority_of_bottle": 9,
--      "bottle_id": "bot_001"
--    }
--    병 정보를 찾지 못했을 때
--    {
--      "status_code": 404,
--      "sender_controller": "DB_Manager",
--      "top_priority_of_bottle": null,
--      "bottle_id": null
--    }
DELIMITER //
CREATE PROCEDURE GetTopPriorityBottle (
    IN p_CurrEqpGroupID CHAR(1),
    IN p_CurrEqpSeqNo CHAR(1),
    IN p_NextEqpGroupID CHAR(1),
    IN p_NextOperID CHAR(1)
)
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE err_code INT;
    DECLARE bottleID CHAR(15);
    DECLARE dispatchingPriority TINYINT;
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_SenderController VARCHAR(20) DEFAULT 'DB_Manager';
    DECLARE v_ErrorMsg VARCHAR(100) DEFAULT 'None';
    DECLARE v_JsonResult JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            err_code = MYSQL_ERRNO,
            v_ErrorMsg = MESSAGE_TEXT;        
        SET v_StatusCode = err_code;
        SET v_JsonResult = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_SenderController,
            'top_priority_of_bottle', NULL,
            'bottle_id', NULL,
            'error_msg', v_ErrorMsg
        );

        SELECT v_JsonResult AS result;
        ROLLBACK;
    END;

    DECLARE cur CURSOR FOR
    SELECT 
        BottleID,
        DispatchingPriority
    FROM 
        tProcBottle
    WHERE 
        CurrEqpGroupID = p_CurrEqpGroupID
        AND CurrEqpSeqNo = p_CurrEqpSeqNo
        AND NextEqpGroupID = p_NextEqpGroupID
        AND NextOperID = p_NextOperID
    ORDER BY 
        DispatchingPriority DESC, 
        StartTime ASC;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    START TRANSACTION;

    OPEN cur;
    FETCH cur INTO bottleID, dispatchingPriority;

    IF NOT done THEN
        SET v_JsonResult = JSON_OBJECT(
            'status_code', v_StatusCode,
            'sender_controller', v_SenderController,
            'top_priority_of_bottle', dispatchingPriority,
            'bottle_id', bottleID,
            'error_msg', v_ErrorMsg
        );
    ELSE
        SET v_JsonResult = JSON_OBJECT(
            'status_code', 404,
            'sender_controller', v_SenderController,
            'top_priority_of_bottle', NULL,
            'bottle_id', NULL,
            'error_msg', 'Bottle not found'
        );
    END IF;

    CLOSE cur;
    COMMIT;

    SELECT v_JsonResult AS result;
END //
DELIMITER ;


============================================================================ 
-- 이벤트 스케줄러 관련 PROCEDURE
============================================================================ 
DELIMITER $$
-- AggregateDailyEqpStatusEvent event scheduler에서 호출
-- 일일가동률 확인을 위해 일일단위로 설비상태정보 집계한다
CREATE PROCEDURE AggregateDailyEqpStatus()
BEGIN
    DECLARE v_CurrentDate DATE;

    -- 현재 날짜 설정
    SET v_CurrentDate = CURDATE();

    -- 집계를 위한 임시 테이블
    CREATE TEMPORARY TABLE tempDailyStatus AS
    SELECT 
        EqpGroupID,
        EqpSeqNo,
        EqpStatus,
        DATE(IFNULL(StartTime, v_CurrentDate)) AS SummaryDate,
        SEC_TO_TIME(SUM(
            TIMESTAMPDIFF(SECOND, 
                IFNULL(StartTime, CONCAT(v_CurrentDate, ' 00:00:00')),
                IFNULL(EndTime, CONCAT(v_CurrentDate, ' 23:59:59'))
            )
        )) AS AccumTmByOneDay
    FROM tChgEqpStatus
    WHERE (StartTime IS NOT NULL OR EndTime IS NOT NULL)
      AND DATE(IFNULL(StartTime, v_CurrentDate)) = v_CurrentDate
      AND DATE(IFNULL(EndTime, v_CurrentDate)) = v_CurrentDate
    GROUP BY EqpGroupID, EqpSeqNo, EqpStatus, SummaryDate;

    -- tDailyEqpStatus 테이블에 데이터 삽입
    INSERT INTO tDailyEqpStatus (EqpGroupID, EqpSeqNo, SummaryDate, EqpStatus, AccumTmByOneDay)
    SELECT 
        EqpGroupID,
        EqpSeqNo,
        SummaryDate,
        EqpStatus,
        AccumTmByOneDay
    FROM tempDailyStatus
    WHERE SummaryDate = v_CurrentDate;

    -- 임시 테이블 삭제
    DROP TEMPORARY TABLE tempDailyStatus;
END $$
DELIMITER ;


DELIMITER $$
-- MoveOldRecordOfEqp2History event scheduler에서 호출
CREATE PROCEDURE MoveOldEqpStatus()
BEGIN
    -- 50일 이상 지난 기록을 tHisChgEqpStatus 테이블로 이동
    INSERT INTO tHisChgEqpStatus (EqpGroupID, EqpSeqNo, EqpStatus, StartTime, EndTime)
    SELECT EqpGroupID, EqpSeqNo, EqpStatus, StartTime, EndTime
    FROM tChgEqpStatus
    WHERE StartTime < DATE_SUB(NOW(), INTERVAL 50 DAY);
    
    -- tChgEqpStatus 테이블에서 50일 이상 지난 기록 삭제
    DELETE FROM tChgEqpStatus
    WHERE StartTime < DATE_SUB(NOW(), INTERVAL 50 DAY);
END $$
DELIMITER ;

-- 이벤트 스케줄러 생성
-- 이벤트 스케줄러 활성화
-- 1. SET GLOBAL event_scheduler = ON;
-- 2. my.cnf 파일에 다음 줄을 추가
--    event_scheduler=ON

DELIMITER $$
-- 장비상태를 1일 단위 집계하여 summary table(tDailyEqpStatus) 저장한다
CREATE EVENT IF NOT EXISTS AggregateDailyEqpStatusEvent
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 23 HOUR + INTERVAL 59 MINUTE + INTERVAL 59 SECOND
DO
BEGIN
    CALL AggregateDailyEqpStatus();
END $$
DELIMITER ;

DELIMITER $$
-- tChgEqpStatus table 오래된 record를 tHisChgEqpStatus table로 이동
CREATE EVENT IF NOT EXISTS MoveOldRecordOfEqp2History
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_DATE + INTERVAL 1 DAY
DO
BEGIN
    CALL MoveOldEqpStatus();
END $$
DELIMITER ;

DELIMITER $$
-- tDailyEqpStatus, tHisProcBotOper, tHisChgEqpStatus history table에서 오래된 record 삭제
CREATE EVENT IF NOT EXISTS CleanupOldRecordsOfTbl
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
DO
BEGIN
    -- tProcBotOper table garbage record 삭제
    DELETE FROM tProcBotOper
    WHERE StartTime < DATE_SUB(NOW(), INTERVAL 6 MONTH);

    -- tDailyEqpStatus table old record 삭제
    DELETE FROM tDailyEqpStatus
    WHERE SummaryDate < DATE_SUB(NOW(), INTERVAL 5 YEAR);

    -- tHisProcBotOper table old record 삭제
    DELETE FROM tHisProcBotOper
    WHERE StartTime < DATE_SUB(NOW(), INTERVAL 5 YEAR);
    
    -- tHisChgEqpStatus table old record 삭제
    DELETE FROM tHisChgEqpStatus
    WHERE StartTime < DATE_SUB(NOW(), INTERVAL 5 YEAR);
END $$
DELIMITER ;


