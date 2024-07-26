
-- GPT prompt
-- 1. 입력 파라메터가
--   'InOutBottle' 이면 '1'
--   'Stocker' 이면 '2'
--   'Analyzer' 이면 '3'
--   'CleaningScrap' 이면 '4'
--   'MOMA' 이면 '5'  그 이외는 '0'을 return 하는 stored function 를 만들어줘.
-- 2. 결과값을 char로 변경해줘
--
DELIMITER //
CREATE FUNCTION f_GetEqpGroupID_FmParameterValue(input_param VARCHAR(20)) 
RETURNS CHAR(1)
BEGIN
    DECLARE return_value CHAR(1) DEFAULT '0';
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- 예외 발생 시 return_value를 '0'으로 설정
        SET return_value = '0';
    END;

    -- 입력 파라미터에 따른 반환 값 설정
    IF input_param = 'InOutBottle' THEN
        SET return_value = '1';
    ELSEIF input_param = 'Stocker' THEN
        SET return_value = '2';
    ELSEIF input_param = 'Analyzer' THEN
        SET return_value = '3';
    ELSEIF input_param = 'CleaningScrap' THEN
        SET return_value = '4';
    ELSEIF input_param = 'MOMA' THEN
        SET return_value = '5';
    ELSE
        SET return_value = '0';
    END IF;

    RETURN return_value;
END //
DELIMITER ;


DELIMITER //
CREATE PROCEDURE sp_UpdateEqpStatus_MstEqp(
    IN p_EqpGroupID CHAR(1),
    IN p_EqpSeqNo INT,
    IN p_EqpStatus VARCHAR(50)
)
BEGIN
    UPDATE tMstEqp
    SET EqpStatus = p_EqpStatus
    WHERE EqpGroupID = p_EqpGroupID AND EqpSeqNo = p_EqpSeqNo;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_UpdatePortEvent_MstEqp(
    IN p_EqpGroupID CHAR(1),
    IN p_EqpSeqNo INT,
    IN p_PortEvent VARCHAR(50),
    IN p_ColumnName VARCHAR(50)
)
BEGIN
    SET @sql = CONCAT('UPDATE tMstEqp SET ', p_ColumnName, ' = ? WHERE EqpGroupID = ? AND EqpSeqNo = ?');
    PREPARE stmt FROM @sql;
    SET @param1 = p_PortEvent;
    SET @param2 = p_EqpGroupID;
    SET @param3 = p_EqpSeqNo;
    EXECUTE stmt USING @param1, @param2, @param3;
    DEALLOCATE PREPARE stmt;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_Update_ProcBottle(
    IN p_BottleID CHAR(15),
    IN p_EqpGroupID CHAR(1),
    IN p_EqpSeqNo CHAR(1)
) 
BEGIN
    UPDATE tProcBottle
    SET CurrEqpGroupID = p_EqpGroupID,
        CurrEqpSeqNo = p_EqpSeqNo,
        CurrOperID = '1',
        EndTime = NULL,
        StartTime = GETDATE()
    WHERE BottleID = p_BottleID;
END //
DELIMITER ;


DELIMITER //
CREATE PROCEDURE sp_UpdatePosition_BottleInfoOfHoleAtInOutBottle(
    IN p_ZoneName VARCHAR(50),
    IN p_BottleID CHAR(15),
    IN p_Position VARCHAR(50)
)
BEGIN
    UPDATE tBottleInfoOfHoleAtInOutBottle
    SET ZoneName = p_ZoneName,
        EventTime = CURRENT_TIMESTAMP,
        BottleID = p_BottleID
    WHERE Position = p_Position;
END //
DELIMITER ;
