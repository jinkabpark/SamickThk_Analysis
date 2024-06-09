============================================================================ 
file name   : sp_SamickAnalysis.sql
author      : JK Park
desc   
   1.    2024-06-06 최초생성

token관련 stored procedure
1.  UpdateEqpStatus                 장비상태를 변경한다. (Idle-->Run, Run-->Idle)
2.  UpdateEqpProcessStatus          장비의 Process상태를 변경한다. (LoadReq, LoadComp, UnLoadReq, UnLoadComp, Idle, Pause, Reserve)
3.  FetchNextOperationFromRoute     차기 공정정보를 가져온다
4.  RetrieveEquipmentStatus         장비상태를 가져온다
5.  RetrieveAllEquipmentStatuses    모든 장비상태를 가져온다
6.  UpdateNextOperation             현재공정완료했을때 차기 공정정보 Set한다.
7.  UpdateNextOper_Insert           LoadComp, UnloadComp에 대한 처리
8.  ProcessLoadUnloadCompletion     세정후 Bottle 재사용을 위해 분석실 내부 Load Port에 반출입기에 입고될때 기존 Data 삭제하고 History 이동한다
9.  UpdateBottleStatus              Bottle상태를 변경한다
10. FetchBottleStatusFmEquipment    Bottle상태를 가져온다
11. RetrieveAllBottleStatuses       모든 Bottle상태를 가져온다
12. RetrievePendingBottles          투입대기중인 Bottle정보를 가져온다
13. RetrieveEmptyBottleCount        설비에서 대기중인 Bottle수량정보를 가져온다
14. FetchBottleProcessHistory       Bottle에서 수행한 공정이력정보를 가져온다

이벤트 스케줄러관련 stored procedure
1.  AggregateDailyEqpStatus         AggregateDailyEqpStatusEvent event scheduler에서 호출
									일일가동률 확인을 위해 일일단위로 설비상태정보 집계한다
2.  MoveOldEqpStatus				MoveOldRecordOfEqp2History event scheduler에서 호출

이벤트 스케줄러 생성
1.  AggregateDailyEqpStatusEvent    장비상태를 1일 단위 집계하여 summary table(tDailyEqpStatus) 저장한다.
2.  MoveOldRecordOfEqp2History      tChgEqpStatus table 오래된 record를 tHisChgEqpStatus table로 이동
3.  CleanupOldRecordsOfTbl          tDailyEqpStatus, tHisProcBotOper, tHisChgEqpStatus history table에서 오래된 record 삭제
============================================================================ 

DELIMITER $$
-- ChangeEqpStatus token event에 대한 처리
-- 장비상태를 변경한다. (Idle-->Run, Run-->Idle)
-- 사용법
--    CALL UpdateEqpStatus('1', '1', 'Run');
-- RETURN
-- {
--    "status_code": 200,
--    "sender_controller": "DB_Manager",
--    "error_msg": "None"
-- }
CREATE PROCEDURE UpdateEqpStatus (
    IN p_EqpGroupID CHAR(1),
    IN p_EqpSeqNo CHAR(1),
    IN p_NewStatus NVARCHAR(10)
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

    -- tMstEqp 테이블의 EqpStatus와 EventTime을 업데이트
    UPDATE tMstEqp
    SET EqpStatus = p_NewStatus,
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


DELIMITER $$
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


DELIMITER $$
-- 차기 공정정보를 가져온다
-- 사용법
--    1. 세션 변수 선언
--       SET @NextEqpGroupID = '';
--       SET @NextOperID = '';
--    2. 저장 프로시저 호출
--       CALL FetchNextOperationFromRoute('1', '1', @NextEqpGroupID, @NextOperID);
--    3. 결과 확인
--       SELECT @NextEqpGroupID AS NextEqpGroupID, @NextOperID AS NextOperID;
CREATE PROCEDURE FetchNextOperationFromRoute (
    IN p_CurrEqpGroupID CHAR(1),
    IN p_CurrOperID CHAR(1),
    OUT p_NextEqpGroupID CHAR(1),
    OUT p_NextOperID CHAR(1)
)
BEGIN
    DECLARE v_NextEqpGroupID CHAR(1);
    DECLARE v_NextOperID CHAR(1);

    SELECT NextEqpGroupID, NextOperID
    INTO v_NextEqpGroupID, v_NextOperID
    FROM tMstRouteOper
    WHERE CurrEqpGroupID = p_CurrEqpGroupID
      AND CurrOperID = p_CurrOperID
    LIMIT 1;

    SET p_NextEqpGroupID = v_NextEqpGroupID;
    SET p_NextOperID = v_NextOperID;
END $$
DELIMITER ;


DELIMITER $$
-- ReqAnalysisEqpStatus token event에 대한 처리
-- 장비상태를 가져온다
-- 사용법
--    CALL RetrieveEquipmentStatus();
--
-- RETURN
-- {
--    "status_code": 200,
--    "sender_controller": "DB_Manager",
--    "eqp_status": "Run",
--    "process_status": "UnloadReq",
--    "error_msg": "None"
-- }
CREATE PROCEDURE RetrieveEquipmentStatus()
BEGIN
    DECLARE v_EqpStatus NVARCHAR(10);
    DECLARE v_ProcessStatus NVARCHAR(12);
    DECLARE v_ErrorMsg NVARCHAR(100) DEFAULT 'None';
    DECLARE v_StatusCode INT DEFAULT 200;
    DECLARE v_JsonResult JSON;

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
    WHERE EqpGroupID = '2'
      AND EqpSeqNo = '1'
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
END $$
DELIMITER ;


DELIMITER $$
-- ReqAllEqpStatus token event에 대한 처리
-- 모든 장비상태를 가져온다
-- 사용법
--    CALL RetrieveAllEquipmentStatuses();
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
CREATE PROCEDURE RetrieveAllEquipmentStatuses()
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


DELIMITER $$
-- 현재공정완료했을때 차기 공정정보 Set한다.
CREATE PROCEDURE UpdateNextOperation (
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


DELIMITER $$
-- 사용안함
-- ProcessLoadUnloadCompletion 통합됨
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


DELIMITER $$
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


DELIMITER $$
-- ChangeBottleInfo token event에 대한 처리
-- Bottle상태를 변경한다
-- 사용법
--    CALL UpdateBottleStatus(
--       'BOTTLE12345',  -- p_BottleID
--       'A',            -- p_EqpGroupID
--       '1',            -- p_EqpSeqNo
--       '2',            -- p_OperID
--       'B',            -- p_NextEqpGroupID
--       '3'             -- p_NextOperID
--    );
--
-- RETURN
-- {
--    "status_code": 200,
--    "sender_controller": "DB_Manager",
--    "error_msg": "None"
-- }
CREATE PROCEDURE UpdateBottleStatus (
    IN p_BottleID CHAR(15),
    IN p_EqpGroupID CHAR(1),
    IN p_EqpSeqNo CHAR(1),
    IN p_OperID CHAR(1),
    IN p_NextEqpGroupID CHAR(1),
    IN p_NextOperID CHAR(1)
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

    -- tProcBottle 테이블의 레코드를 업데이트
    UPDATE tProcBottle
    SET CurrEqpGroupID = p_EqpGroupID,
        CurrEqpSeqNo = p_EqpSeqNo,
        CurrOperID = p_OperID,
        NextEqpGroupID = p_NextEqpGroupID,
        NextOperID = p_NextOperID,
        EventTime = v_CurrentTime
    WHERE BottleID = p_BottleID;

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


DELIMITER $$
-- ReqBottleInfoFmEqp token event에 대한 처리
-- Bottle상태를 가져온다
-- 사용법
--    CALL FetchBottleStatusFmEquipment('1', '1');
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
CREATE PROCEDURE FetchBottleStatusFmEquipment (
    IN p_EqpGroupID CHAR(1),
    IN p_EqpSeqNo CHAR(1)
)
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
    FROM tProcBottle 
    WHERE CurrEqpGroupID = p_EqpGroupID AND CurrEqpSeqNo = p_EqpSeqNo;

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
            WHERE CurrEqpGroupID = p_EqpGroupID 
              AND CurrEqpSeqNo = p_EqpSeqNo
            ORDER BY EventTime
        ),
        'error_msg', v_ErrorMsg
    );

    COMMIT;

    SELECT v_JsonResult AS result;
END $$
DELIMITER ;


DELIMITER $$
-- ReqAllBottlesInfo token event에 대한 처리
-- 모든 Bottle상태를 가져온다
-- 사용법
--    CALL RetrieveAllBottleStatuses();
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
CREATE PROCEDURE RetrieveAllBottleStatuses()
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


DELIMITER $$
-- InputWaitingBottleInfoFmEqp token event에 대한 처리
-- 투입대기중인 Bottle정보를 가져온다
-- 사용법
--    CALL RetrievePendingBottles('2', '1');
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
CREATE PROCEDURE RetrievePendingBottles (
    IN p_NextEqpGroupID CHAR(1),
    IN p_NextOperID CHAR(1)
)
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
    FROM tProcBottle 
    WHERE NextEqpGroupID = p_NextEqpGroupID AND NextOperID = p_NextOperID;

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
            WHERE NextEqpGroupID = p_NextEqpGroupID AND NextOperID = p_NextOperID
            ORDER BY BottleID
        ),
        'error_msg', v_ErrorMsg
    );

    COMMIT;

    SELECT v_JsonResult AS result;
END $$
DELIMITER ;


DELIMITER $$
-- GetCountEmptyBottleAtInOutBottle token event에 대한 처리
-- 설비에서 대기중인 Bottle수량정보를 가져온다
-- 사용법
--    CALL RetrieveEmptyBottleCount('1', '1');
-- RETURN
-- {
--    "status_code": 200,
--    "sender_controller": "DB_Manager",
--    "total_cnt_of_empty_bottle": 10,
--    "error_msg": "None"
-- }
CREATE PROCEDURE RetrieveEmptyBottleCount (
    IN p_CurrEqpGroupID CHAR(1),
    IN p_CurrEqpSeqNo CHAR(1)
)
BEGIN
    DECLARE v_TotalCntOfEmptyBottle INT;
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

    -- 테이블의 총 빈 병 레코드 수를 계산
    SELECT COUNT(*) INTO v_TotalCntOfEmptyBottle 
    FROM tProcBottle 
    WHERE CurrEqpGroupID = p_CurrEqpGroupID 
      AND CurrEqpSeqNo = p_CurrEqpSeqNo;

    COMMIT;

    -- JSON 형식으로 결과 반환
    SET v_JsonResult = JSON_OBJECT(
        'status_code', v_StatusCode,
        'sender_controller', v_SenderController,
        'total_cnt_of_empty_bottle', v_TotalCntOfEmptyBottle,
        'error_msg', v_ErrorMsg
    );

    SELECT v_JsonResult AS result;
END $$
DELIMITER ;


DELIMITER $$
-- Req4BottleProcessHistory token event에 대한 처리
-- Bottle에서 수행한 공정이력정보를 가져온다
-- 사용법
--    CALL FetchBottleProcessHistory('Bot_001');
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
CREATE PROCEDURE FetchBottleProcessHistory (
    IN p_BottleID CHAR(15)
)
BEGIN
    DECLARE v_TotalCntOfProcess INT;
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

    -- 테이블의 총 프로세스 레코드 수를 계산
    SELECT COUNT(*) INTO v_TotalCntOfProcess 
    FROM tProcBotOper 
    WHERE BottleID = p_BottleID;

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
            WHERE BottleID = p_BottleID
            ORDER BY EqpGroupID, OperID
        ),
        'error_msg', v_ErrorMsg
    );

    COMMIT;

    SELECT v_JsonResult AS result;
END $$
DELIMITER ;


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


