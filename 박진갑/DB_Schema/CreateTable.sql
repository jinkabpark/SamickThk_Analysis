Equipment에 port 추가
Script 처리방식 변경
이슈
   착공(작업시작), 완공(작업종료)에 대한 재정의 필요
   
   
============================================================================ 
file name   : CreateTable.sql
author      : JK Park
desc   
   1.    2024-06-01 최초생성
   2.    2024-06-16 의사결정*) 수동모드에서 이동형 협업로봇 동작을 UI에서 MOMA로 직접 전달할지, 
                            Dispatcher 통해 전달힐지는 의사결정 필요.
   
-- ============================================================================ 
-- Table Space 명   : Master
-- 내 용            : Master관련 table을 관리하는 table space
--
-- 관련 MASTER Table
--
--           No.   Table 명                   Size
--          ----  -----------------         --------
--            1     tMstUser                  1 K
--            2     tMstEqpGroup               1 K
--            3     tMstEqp                    1 K
--            4     tMstOperation              1 K
--            5     tMstBottle                 1 K
--            6     tMstRouteOper              1 K
--            7     tMstScript4Manipulator     1 K
--            8     tMstScript4UR              1 K
--            9     tMstScript4CoOperRobot     1 K
--           10     tMstScriptID4CoOperRobot   1 K
--           11     tMstScriptBody4CoOperRobot 1 K
--           12     tMstToken                  1 K
-- ============================================================================ 
-- Table Space 명   : Process
-- 내 용            : 공정관련 table을 관리하는 table space
--
-- 관련 Master Table
--           No.    Table 명                  Size   
--          ----  ------------------------  ------------
--            1     tLaboratoryDemandInfo
--            2     tProcBottle
--            3     tProcBotOper
--            4     tChgEqpStatus
--            5     tDailyEqpStatus

-- ============================================================================ 
-- Table Space 명   : History
-- 내 용            : 공정관련 table을 관리하는 table space
--
-- 관련 Master Table
--           No.    Table 명             Size   
--          ----  --------------------  ------------
--            1     tHisProcBotOper
--            2     tHisChgEqpStatus
-- ========================================================================================
--   Table No             : 1
--   Table 명              : tMstUser
--   내  용                : 사용자를 관리하는 Table
--   성  격                : Master
--   보존기간                : 영구
--   Record 발생건수(1일)    :
--   Total Record 수      : 5
--   Record size          : 31
--   Total size           : 155 = 5 * 31
--   관리화면 유/무           : 유
--   P.K                  : UserID
--   관련 Table            : 
--   이 력
--          1.2024-06-03 : 최초 생성
--
-- ========================================================================================
DROP TABLE tMstUser;;

CREATE TABLE tMstUser; (
   UserID                 NVARCHAR(30) NOT NULL,    -- 사용자ID (사번)
   UserName               NVARCHAR(10),             -- 사용자ID (사번)
   Password               NVARCHAR(16),             -- Password, 패스워드 속성
   ClassID                TINYINT,                  -- 사용자 권한 등급 (1:MONITORING, 3:OP, 5:MASTER, 9:DEV) 
   UpdateTime             DATETIME
) ON [Master];

ALTER TABLE tMstUser 
      ADD CONSTRAINT tMstUser_PK PRIMARY KEY (UserID) ON [MasterIdx];
      
INSERT INTO tMstUser VALUES ('9999999', 'Developer',    'DEVELOPER',    9,  NULL);

-- ========================================================================================
--   Table No             : 2
--   Table 명              : tMstEqpGroup
--   내  용                : LIMS 설비군을 관리하는 Table
--   성  격                : Master
--   보존기간                : 영구
--   Record 발생건수(1일)    :
--   Total Record 수      : 5
--   Record size          : 31
--   Total size           : 155 = 5 * 31
--   관리화면 유/무           : 무
--   P.K                  : EqpGroupID
--   관련 Table            : 
--   이 력
--          1.2024-06-01 : 최초 생성
--
-- ========================================================================================
DROP TABLE tMstEqpGroup;

CREATE TABLE tMstEqpGroup (
   EqpGroupID             CHAR(1) NOT NULL,         -- 설비군ID
   EqpGroupName           NVARCHAR(30),             -- 설비명 
) ON [Master];

ALTER TABLE tMstEqpGroup 
      ADD CONSTRAINT tMstEqpGroup_PK PRIMARY KEY (EqpGroupID) ON [MasterIdx];
      
INSERT INTO tMstEqpGroup VALUES ('0', N'Dummy');        -- Bottle 잡지않고 이동하는 경우 사
INSERT INTO tMstEqpGroup VALUES ('1', N'반출입기');
INSERT INTO tMstEqpGroup VALUES ('2', N'Stocker');      -- Stocker #1호기
INSERT INTO tMstEqpGroup VALUES ('3', N'분석기');
INSERT INTO tMstEqpGroup VALUES ('4', N'폐기설비');
INSERT INTO tMstEqpGroup VALUES ('5', N'이동형협업로봇');



-- ========================================================================================
--   Table No             : 3
--   Table 명             : tMstEqp 
--   내  용               : LIMS 설비군을 관리하는 Table
--                         1) Bottle 반출입기의 경우 실험실내 2개 Port 있고, 실험실 외부에 2개 Port 있음
--                            실험실 외부에서 발생하는 LoadReq, LoadComp event는 무시한다.
--                            실험실 외부 Event는 이동형 협업로봇 동작과는 무관. 작업자 관계만 있음.
--                         2) 현재는 설비군별 장비가 1대지만, 향후 장비추가를 대비해서 EqpSeqNo 추가
--                         3) Bottle 반출입기, 스토커 Full인 경우 상태를 'Trouble' 변경
--                         4) 반송(Dispatch)를 위한 설비상태는 현설비 UnloadPort에서 UnloadReq, 
--                            Route상 Next설비는 LoadReq이면 반송을 하기 전에
--                            Dispatcher는 Next설비의 LoadPort의 상태를 Reserve상태로 변경하여
--                            Port를 예약(선점)한다.
--   성  격               : Master
--   보존기간              : 영구
--   Record 발생건수(1일) :
--   Total Record 수      : 5
--   Record size          : 46
--   Total size           : 180 = 5 * 36
--   관리화면 유/무           : 무
--   P.K                  : EqpGroupID, EqpSeqNo
--   관련 Table           : 
--   이 력
--          1. 2024-06-01 : 최초 생성
--          2. 2024-06-16 : ProcessStatus 삭제하고 (각 Port별 상태에 대한 개별관리 필요)
--                          LoadPort_1, LoadPort_2, UnloadPort_1, UnloadPort_2 신규생성
--                          Bottle 반출입기, Stocker, 분석기, MOMA 작업단위는 의뢰단위(수량이 다를수 있음)
--                          Bottle 반출입기의 경우
--                             실험실 내부 Port : LoadPort_1, UnloadPort_1
--                             실험실 외부 Port : LoadPort_2, UnloadPort_2 정의함
--                          분석기는 Port 없이 MOMA에서 직접 Spot에 bottle 투입, 반출 함
--                          stocker는 Port 없이 MOMA에서 직접 Port(세로)-slot(가로)에 bottle 투입, 반출 함
--          3. 2024-06-19 : 분석기 수량을 3대로 변경함.
--                          EqpStatus value에 Waiting추가. 설비에서 작업이 끝나고 작업자 판정을 기다리는 상태.
--                             작업자 판정이 끝나고 모든 bottle 추출하면 장비상태를 idle 변경함
--                             Run --> Waiting --> Idle 순환
--                          CapacityOfHole field 추가
--
-- ========================================================================================
DROP TABLE tMstEqp;

CREATE TABLE tMstEqp (
   EqpGroupID             CHAR(1) NOT NULL,         -- 설비군ID
   EqpSeqNo               CHAR(1) NOT NULL,         -- 호기 (1부터 시작)
   EqpName                NVARCHAR(30),             -- 설비명 
   CapacityOfHole         TINYINT,                  -- 설비별 hole(병을 처리할수 있는) 케파
   EqpStatus              NVARCHAR(10),             -- 장비상태 (PowerOn, PowerOff, Run, Waiting, Idle, Pause, Trouble, Maintenance)
   //ProcessStatus          NVARCHAR(12),             -- 진행 상태(LoadReq, LoadComp, UnLoadReq, UnLoadComp, Reserve)
   LoadPort_1             NVARCHAR(12),             -- 진행 상태(LoadReq, LoadComp, Reserve)
   LoadPort_2             NVARCHAR(12),             -- 진행 상태(LoadReq, LoadComp, Reserve)
   UnloadPort_1           NVARCHAR(12),             -- 진행 상태(UnLoadReq, UnLoadComp, Reserve)
   UnloadPort_2           NVARCHAR(12),             -- 진행 상태(UnLoadReq, UnLoadComp, Reserve)
   EventTime              DATETIME,                 -- Event Time
   EqpTimeWriteLog        INT default 0             -- 장비 내부 LOG 저장 시간
) ON [Master];

ALTER TABLE tMstEqp 
      ADD CONSTRAINT tMstEqp_PK PRIMARY KEY (EqpGroupID, EqpSeqNo) ON [MasterIdx];
ALTER TABLE tMstEqp 
      ADD CONSTRAINT tMstEqp_FK FOREIGN KEY (EqpGroupID) REFERENCES tMstEqpGroup(EqpGroupID) ON [MasterIdx];
ALTER TABLE tMstEqp 
      ADD CONSTRAINT tMstEqp_CHK CHECK (EqpStatus in ("PowerOn", "PowerOff", "Run", "Waiting", "Idle", "Trouble", "Maintenance")) ON [MasterIdx];
      
INSERT INTO tMstEqp VALUES ('1', '1', N'반출입기', 90, "Idle", "LoadReq", null, null, null, null);
INSERT INTO tMstEqp VALUES ('2', '1', N'Stocker', 96, "Idle", "LoadReq", null, null, null, null);      -- Stocker #1호기
INSERT INTO tMstEqp VALUES ('3', '1', N'분석기 1호기', 12, "Idle", "LoadReq", null, null, null, null);
INSERT INTO tMstEqp VALUES ('3', '2', N'분석기 2호기', 12, "Idle", "LoadReq", null, null, null, null);
INSERT INTO tMstEqp VALUES ('3', '3', N'분석기 3호기', 12, "Idle", "LoadReq", null, null, null, null);
INSERT INTO tMstEqp VALUES ('4', '1', N'폐기설비', 1, "Idle", "LoadReq", null, null, null, null);
INSERT INTO tMstEqp VALUES ('5', '1', N'이동형협업로봇', 12, "Idle", "LoadComp", null, null, null, null);


-- ========================================================================================
--   Table No             : 4
--   Table 명             : tMstOperation
--   내  용               : LIMS Opertaion을 관리하는 Master Table
--                          - 공정번호 구성 = EqpGroupID + OperGroupID + OperID
--                            . EqpGroupID   : 설비군 정보
--                            . OperGroupID : 공정그룹 정보
--                            . OperID      : 공정그룹중에서 Sequential Number
--   성  격               : Master
--   보존기간              : 영구
--   Record 발생건수(1일)   :
--   Total Record 수      : 14
--   Record Size          : 43
--   Total Size           : 5868 = 14 * 163
--   관리화면 유/무           : 무
--   P.K                  : EqpGroupID, OperID
--   관련 Table             : tMstOperGroup(EqpGroupID)
--   이  력     
--          1. 2024-06-01 : 최초 생성
--
-- ========================================================================================
DROP TABLE tMstOperation;

CREATE TABLE tMstOperation (
   EqpGroupID             CHAR(1) NOT NULL,         -- 설비군 ID 
   --OperGroupID          CHAR(1) NOT NULL,         -- Operation Group 
   OperID                 CHAR(1) NOT NULL,         -- 작업 ID
   OperName               NVARCHAR(40)              -- Operation Description   
) ON [Master];

ALTER TABLE tMstOperation
      ADD CONSTRAINT tMstOperation_PK PRIMARY KEY (EqpTypeID, OperID) ON [MasterIdx];
ALTER TABLE tMstOperation 
      ADD CONSTRAINT tMstEqp_FK FOREIGN KEY (EqpGroupID) REFERENCES tMstEqpGroup(EqpGroupID) ON [MasterIdx];

INSERT INTO tMstOperation VALUES ('1', '1', N'공병Zone 대기');     	-- 세정후 공병투입(세정후 재사용을 위하여 투입)
INSERT INTO tMstOperation VALUES ('1', '2', N'시료채취중');            	-- 작업의뢰자가 시료채취
INSERT INTO tMstOperation VALUES ('1', '3', N'실병Zone 대기');			-- 시료채취후 실병투입

INSERT INTO tMstOperation VALUES ('2', '1', N'분석 작업중');
INSERT INTO tMstOperation VALUES ('3', '1', N'Stocker 입고');       	-- 
INSERT INTO tMstOperation VALUES ('4', '1', N'폐기설비 작업중');
INSERT INTO tMstOperation VALUES ('5', '1', N'이동형협업로봇 이동중');


-- ========================================================================================
--   Table No             : 5
--   Table 명             : tMstBottle
--   내  용                : Bottle Master정보을 관리하는 Table
--
--   성  격               : Master
--   보존기간              : 영구
--   Record 발생건수(1일)   :
--   Total Record 수      : 5
--   Record size          : 9
--   Total size           : 180 = 5 * 36
--   관리화면 유/무           : 유
--   P.K                  : BottleID
--   관련 Table            : 
--   이 력
--          1. 2024-06-01 : 최초 생성
--
-- ========================================================================================
DROP TABLE tMstBottle;

CREATE TABLE tMstBottle (
   BottleID               CHAR(10) NOT NULL,         -- Bottle ID
   Creation               DATETIME,                  -- 생성일
   Termination               DATETIME                  -- 폐기일
) ON [Master];

ALTER TABLE tMstBottle
      ADD CONSTRAINT tMstBottle_PK PRIMARY KEY (BottleID) ON [MasterIdx];

-- ========================================================================================
--   Table No             : 6
--   Table 명             : tMstRouteOper
--   내  용                : LIMS Route을 관리하는 Table
--                         분석실에서 현재 1개 Route로 처리가능함
--                         분석기에서 판정후 Stocker Or 폐기/모사 이동할수 있음
--                         주의) Dispatcher는 분석의뢰자가 Bottle 반출입기 투입후 Stocker에서 투입할 Bottle 없고 
--                              분석기 상태가 Idle일때는 Stocker에 분석대기중인 Bottle없을때, Bottle 반출입기에서 분석기로 바로 이동
--   성  격               : Master
--   보존기간              : 영구
--   Record 발생건수(1일)   :
--   Total Record 수      : 5
--   Record size          : 5
--   Total size           : 180 = 5 * 36
--   관리화면 유/무           : 유
--   P.K                  : BottleID
--   관련 Table            : 
--   이 력
--          1. 2024-06-01 : 최초 생성
--
-- ========================================================================================
DROP TABLE tMstRouteOper;

CREATE TABLE tMstRouteOper (
   RouteID                CHAR(1) NOT NULL,         -- Route ID
   -- 현공정에 대한 정의  
   CurrEqpGroupID         CHAR(1) NOT NULL,         -- 현재 설비군 ID 
   CurrOperID             CHAR(1) NOT NULL,         -- 현재 작업 ID
   -- 다음공정에 대한 정의  
   NextEqpGroupID         CHAR(1) NOT NULL,         -- 차기 설비군 ID 
   NextOperID             CHAR(1) NOT NULL          -- 차기 작업 ID
) ON [Master];

ALTER TABLE tMstRouteOper
       ADD CONSTRAINT tMstRoute_PK PRIMARY KEY (RouteID, CurrEqpGroupID, CurrOperID, NextEqpGroupID) ON [MasterIdx];

INSERT INTO tMstRouteOper VALUES ('1', '0', '0', '1', '1');
INSERT INTO tMstRouteOper VALUES ('1', '1', '1', '1', '2');     -- 작업자가 시료채취를 위해 반출요청
INSERT INTO tMstRouteOper VALUES ('1', '1', '2', '1', '3');     -- 시료채취
INSERT INTO tMstRouteOper VALUES ('1', '1', '3', '1', '4');     -- 작업자가 시료채취후 투입
INSERT INTO tMstRouteOper VALUES ('1', '1', '4', '3', '1');     -- UnloadRequest event (Stocker 이동)
INSERT INTO tMstRouteOper VALUES ('1', '1', '5', '1', '1');     -- 세정후 재사용을 위하여 Bottle 반출입기에 보관

INSERT INTO tMstRouteOper VALUES ('1', '2', '1', '3', '1');     -- 분석후 Stocker 이동
INSERT INTO tMstRouteOper VALUES ('1', '3', '1', '2', '1');
INSERT INTO tMstRouteOper VALUES ('1', '2', '1', '5', '1');     -- 분석후 폐기/모사 이동

-- ========================================================================================
--   Table No             : 7
--   Table 명              : tMstScript4Manipulator
--   내  용                : Manipulator Script 관리하는 Table
--   성  격                : Master
--   보존기간                : 영구
--   Record 발생건수(1일)    :
--   Total Record 수      : 5
--   Record size          : 31
--   Total size           : 155 = 5 * 31
--   관리화면 유/무           : 유
--   P.K                  : FmEqpGroupID, ToEqpGroupID, ScriptSeqNo
--   관련 Table            : 
--   이 력
--          1.2024-06-03 : 최초 생성
--          2.2024-06-16 : 사용 안함
--                         tMstScriptID4CoOperRobot, tMstScriptBody4CoOperRobot 2개 table로 통합
--
-- ========================================================================================
DROP TABLE tMstScript4Manipulator;

CREATE TABLE tMstScript4Manipulator; (
   FmEqpGroupID           CHAR(1) NOT NULL,         -- 이동시작설비
   ToEqpGroupID           CHAR(1) NOT NULL,         -- 이동종료설비   
   ScriptSeqNo            INT,                      -- Script Sequence No
   X_Coordinate           FLOAT,                    -- X 좌표
   Y_Coordinate           FLOAT,                    -- Y 좌표
   Orientation            FLOAT                     -- 방향
) ON [Master];

ALTER TABLE tMstScript4Manipulator 
      ADD CONSTRAINT tMstScript4Manipulator_PK PRIMARY KEY (FmEqpGroupID, ToEqpGroupID, ScriptSeqNo) ON [MasterIdx];
      
INSERT INTO tMstScript4Manipulator VALUES ('1', '3', 1, 1.0, 2.0, 1.57);      -- MIR 로봇을 지정된 위치로 이동
INSERT INTO tMstScript4Manipulator VALUES ('1', '3', 2, 1.1, 2.1, 1.57);      -- 물체를 집는 위치로 이동
INSERT INTO tMstScript4Manipulator VALUES ('1', '3', 3, 2.0, 3.0, 1.57);      -- 로봇을 다른 위치로 이동 (물체 운반)
INSERT INTO tMstScript4Manipulator VALUES ('1', '3', 4, 0.0, 0.0, 0.0);       -- 홈 포지션으로 복귀


-- ========================================================================================
--   Table No             : 8
--   Table 명              : tMstScript4UR
--   내  용                : tMstScript4UR Script 관리하는 Table
--   성  격                : Master
--   보존기간                : 영구
--   Record 발생건수(1일)    :
--   Total Record 수      : 5
--   Record size          : 31
--   Total size           : 155 = 5 * 31
--   관리화면 유/무           : 유
--   P.K                  : EqpGroupID, ProcessStatus, ScriptSeqNo
--   관련 Table            : 
--   이 력
--          1.2024-06-03 : 최초 생성
--          2.2024-06-16 : 사용 안함
--                         tMstScriptID4CoOperRobot, tMstScriptBody4CoOperRobot 2개 table로 통합
--
-- ========================================================================================

DROP TABLE tMstScript4UR;

CREATE TABLE tMstScript4UR; (
   EqpGroupID             CHAR(1) NOT NULL,         -- 이동시작설비
   ProcessStatus          NVARCHAR(10) NOT NULL,    -- Loading, Unloading
   ScriptSeqNo            INT,                      -- Script Sequence No
   ScriptBody             NVARCHAR(256)             -- Script 내용
) ON [Master];

ALTER TABLE tMstScript4UR 
      ADD CONSTRAINT tMstScript4UR_PK PRIMARY KEY (EqpGroupID, ProcessStatus, ScriptSeqNo) ON [MasterIdx];
      
INSERT INTO tMstScript4UR VALUES ('1',  'Loading',  1,  '0, -1.5708, 0, -1.5708, 0, 0');                    -- 로봇 초기화 및 홈 포지션으로 이동
INSERT INTO tMstScript4UR VALUES ('1',  'Loading',  2,  '1.5708, -1.5708, 1.5708, -1.5708, 1.5708, 0');     -- 첫 번째 위치로 이동 
INSERT INTO tMstScript4UR VALUES ('1',  'Loading',  3,  '-1.5708, -1.5708, -1.5708, -1.5708, -1.5708, 0');  -- 두 번째 위치로 이동
INSERT INTO tMstScript4UR VALUES ('1',  'Loading',  4,  '0, -1.5708, 0, -1.5708, 0, 0');                    -- 홈 포지션으로 복귀

-- ========================================================================================
--   Table No             : 9
--   Table 명              : tMstScript4CoOperRobot
--   내  용                : 협업로봇에서 사용하는 모든 Device(Manipulator, UR...)의 Script 관리하는 Table
--                           tMstScript4Manipulator, tMstScript4UR table 통합
--   성  격                : Master
--   보존기간                : 영구
--   Record 발생건수(1일)    :
--   Total Record 수      : 5
--   Record size          : 31
--   Total size           : 155 = 5 * 31
--   관리화면 유/무           : 유
--   P.K                  : FmEqpGroupID, ToEqpGroupID, ScriptSeqNo
--   관련 Table            : 
--   이 력
--          1.2024-06-03 : 최초 생성
--          2.2024-06-04 : BodyOfJsonType field 추가
--                         X_Coordinate_MIR, Y_Coordinate_MIR, Orientation_MIR, ScriptBody_UR field 삭제
--          3.2024-06-16 : 사용 안함
--                         tMstScript4CoOperRobot table 삭제하고  tMstScriptID4CoOperRobot, tMstScriptBody4CoOperRobot 
--                         2개 table 분리
--
-- ========================================================================================
DROP TABLE tMstScript4CoOperRobot;

CREATE TABLE tMstScript4CoOperRobot; (
   FmEqpGroupID           CHAR(1) NOT NULL,         -- 이동시작설비
   ToEqpGroupID           CHAR(1) NOT NULL,         -- 이동종료설비   
   ScriptSeqNo            INT,                      -- Script Sequence No
   TgtObject              NVARCHAR(10),             -- Object (UR, MIR, Gripper, Vision), 즉 Table명
   BodyOfJsonType         TEXT,                     -- 장치별 JSON Type Script Body
   Description            TEXT                      -- Script에 대한 내용기술   
   --X_Coordinate_MIR       FLOAT,                    -- X 좌표
   --Y_Coordinate_MIR       FLOAT,                    -- Y 좌표
   --Orientation_MIR        FLOAT,                    -- 방향   
   --ScriptBody_UR          NVARCHAR(256)             -- Script 내용   
}  ON [Master];
   
ALTER TABLE tMstScript4CoOperRobot 
      ADD CONSTRAINT tMstScript4CoOperRobot_PK PRIMARY KEY (FmEqpGroupID, ToEqpGroupID, ScriptSeqNo) ON [MasterIdx];

INSERT INTO tMstScript4CoOperRobot VALUES ('1', '3', 1, "MIR", '{"X":"1.0", "Y":"2.0", "Orientation":"1.57"}', "MIR 로봇을 지정된 위치로 이동");
INSERT INTO tMstScript4CoOperRobot VALUES ('1', '3', 1, "MIR", '{"X":"1.0", "Y":"2.0", "Orientation":"1.57"}', "MIR 로봇을 지정된 위치로 이동");
INSERT INTO tMstScript4CoOperRobot VALUES ('1', '3', 2, "MIR", '{"X":"1.1", "Y":"2.1", "Orientation":"1.57"}', "물체를 집는 위치로 이동");
INSERT INTO tMstScript4CoOperRobot VALUES ('1', '3', 3, "MIR", '{"X":"2.0", "Y":"3.0", "Orientation":"1.57"}', "로봇을 다른 위치로 이동 (물체 운반)");
INSERT INTO tMstScript4CoOperRobot VALUES ('1', '3', 4, "MIR", '{"X":"0.0", "Y":"0.0", "Orientation":"0.0"}', "홈 포지션으로 복귀");

INSERT INTO tMstScript4CoOperRobot VALUES ('1', '3', 5, "UR", '{"Body":"0, -1.5708, 0, -1.5708, 0, 0"}', "로봇을 다른 위치로 이동 (물체 운반)");
INSERT INTO tMstScript4CoOperRobot VALUES ('1', '3', 6, "UR", '{"Body":"1.5708, -1.5708, 1.5708, -1.5708, 1.5708, 0"}', "로봇을 다른 위치로 이동 (물체 운반)");
INSERT INTO tMstScript4CoOperRobot VALUES ('1', '3', 7, "UR", '{"Body":"-1.5708, -1.5708, -1.5708, -1.5708, -1.5708, 0"}', "로봇을 다른 위치로 이동 (물체 운반)");
INSERT INTO tMstScript4CoOperRobot VALUES ('1', '3', 8, "UR", '{"Body":"0, -1.5708, 0, -1.5708, 0, 0"}', "로봇을 다른 위치로 이동 (물체 운반)");


-- ========================================================================================
--   Table No             : 10
--   Table 명              : tMstScriptID4CoOperRobot
--   내  용                : EqpGroupID별로 이동형 협업로봇의 동작(Loading,Unloading시) 동일할수 있지만 확장성 고려하여 별도관리
--                          협업로봇에서 사용하는 모든 Device(UR, Manipulator, Gripper, Vision..)의 Script ID 관리하는 Table
--                          자동운전할때 사용. 
--                          Loading, Unloading할때 구동 Device(UR, Manipulator, Gripper, Vision..) 전체동작을 ID로 관리
--                          Script Body는 각각 Device에서 관리한다.
--                          Dispatcher는 Loading, Unloading시 Script ID를 설비에 전달(명령)한다.
--   성  격                : Master
--   보존기간                : 영구
--   Record 발생건수(1일)    :
--   Total Record 수      : 5
--   Record size          : 31
--   Total size           : 155 = 5 * 31
--   관리화면 유/무           : 유
--   P.K                  : EqpGroupID, ProcessStatus, ObjectOfCoOperRobot, ScriptID
--   관련 Table            : 
--   이 력
--          1.2024-06-16 : 최초 생성
--
-- ========================================================================================
DROP TABLE tMstScriptID4CoOperRobot;

CREATE TABLE tMstScriptID4CoOperRobot; (
   EqpGroupID             CHAR(1) NOT NULL,         -- 대상설비 (Bottle 반출입기, Stocker, 분석기, 폐기모사)
   ProcessStatus          NVARCHAR(10) NOT NULL,    -- Loading, Unloading
   ObjectOfCoOperRobot    NVARCHAR(10) NOT NULL,    -- 이동형 협업로봇 Object (UR, MIR, Gripper, Vision), 즉 Device명
   ScriptID               INT NOT NULL,             -- Script ID No
   Activation             CHAR(1),                  -- 1:활성화, 0:비활성화
   ScriptDescription      NVARCHAR(256)             -- Script 내용
}  ON [Master];
   
ALTER TABLE tMstScriptID4CoOperRobot 
      ADD CONSTRAINT tMstScriptID4CoOperRobot_PK PRIMARY KEY (EqpGroupID, ProcessStatus, ObjectOfCoOperRobot, ScriptID) ON [MasterIdx];

ALTER TABLE tMstScriptID4CoOperRobot 
      ADD CONSTRAINT tMstScriptID4CoOperRobot_CHK CHECK (Activation in ('0', '1')) ON [MasterIdx];
      
INSERT INTO tMstScriptID4CoOperRobot VALUES ('1', 'Loading', "UR", 1, '1', 'UR Loading시 동작정의');                    -- 
INSERT INTO tMstScriptID4CoOperRobot VALUES ('1', 'Loading', "UR", 2, '0', 'UR Loading시 동작 예비 1');                    -- 

-- ========================================================================================
--   Table No             : 11
--   Table 명              : tMstScriptBody4CoOperRobot
--   내  용                : EqpGroupID별로 이동형 협업로봇의 동작(Loading,Unloading시) 동일할수 있지만 확장성 고려하여 별도관리
--                          협업로봇에서 사용하는 모든 Device(UR, Manipulator, Gripper, Vision..)의 Script ID 관리하는 Table
--                          수동운전할때 사용. 
--                          Loading, Unloading할때 구동 Device(UR, Manipulator, Gripper, Vision..) 세부동작에 대한 관리
--                          UI, Dispatcher는 Loading, Unloading시 Script 각각 동작을 설비에 전달(명령)한다.
--                          의사결정*) UI에서 직접 MOMA에 전달할지, Dispatcher 통해 전달힐지는 의사결정 필요.
--   성  격                : Master
--   보존기간                : 영구
--   Record 발생건수(1일)    :
--   Total Record 수      : 5
--   Record size          : 31
--   Total size           : 155 = 5 * 31
--   관리화면 유/무           : 유
--   P.K                  : EqpGroupID, ProcessStatus, ObjectOfCoOperRobot, ScriptID, ScriptSeqNoOfBody
--   관련 Table            : 
--   이 력
--          1.2024-06-16 : 최초 생성
--
-- ========================================================================================
DROP TABLE tMstScriptBody4CoOperRobot;

CREATE TABLE tMstScriptBody4CoOperRobot; (
   EqpGroupID             CHAR(1) NOT NULL,         -- 대상설비 (Bottle 반출입기, Stocker, 분석기, 폐기모사)
   ProcessStatus          NVARCHAR(10) NOT NULL,    -- Loading, Unloading
   ObjectOfCoOperRobot    NVARCHAR(10) NOT NULL,    -- 이동형 협업로봇 Object (UR, MIR, Gripper, Vision), 즉 Device명
   ScriptID               INT NOT NULL,             -- Script ID No
   ScriptSeqNoOfBody      INT NOT NULL,             -- Script Body의 Sequence No
   ScriptBody             NVARCHAR(256),            -- Script 구분동작
   ScriptDescription      NVARCHAR(256)             -- Script 내용
}  ON [Master];
   
ALTER TABLE tMstScriptBody4CoOperRobot 
      ADD CONSTRAINT tMstScriptBody4CoOperRobot_PK PRIMARY KEY (EqpGroupID, ProcessStatus, ObjectOfCoOperRobot, ScriptID, ScriptSeqNoOfBody) ON [MasterIdx];

ALTER TABLE tMstScriptID4CoOperRobot 
      ADD CONSTRAINT tMstScriptBody4CoOperRobot_FK FOREIGN KEY (EqpGroupID, ProcessStatus, ObjectOfCoOperRobot, ScriptID, ScriptSeqNoOfBody) 
      REFERENCES tMstEqpGroup(EqpGroupID, ProcessStatus, ObjectOfCoOperRobot, ScriptID, ScriptSeqNoOfBody) ON [MasterIdx];


INSERT INTO tMstScript4CoOperRobot VALUES ('1', 'Loading', "MIR", 3, 1, '{"X":"1.0", "Y":"2.0", "Orientation":"1.57"}', "MIR 로봇을 지정된 위치로 이동");
INSERT INTO tMstScript4CoOperRobot VALUES ('1', 'Loading', "MIR", 3, 2, '{"X":"1.0", "Y":"2.0", "Orientation":"1.57"}', "MIR 로봇을 지정된 위치로 이동");
INSERT INTO tMstScript4CoOperRobot VALUES ('1', 'Loading', "MIR", 3, 3, '{"X":"1.1", "Y":"2.1", "Orientation":"1.57"}', "물체를 집는 위치로 이동");
INSERT INTO tMstScript4CoOperRobot VALUES ('1', 'Loading', "MIR", 3, 4, '{"X":"2.0", "Y":"3.0", "Orientation":"1.57"}', "로봇을 다른 위치로 이동 (물체 운반)");
INSERT INTO tMstScript4CoOperRobot VALUES ('1', 'Loading', "MIR", 3, 5, '{"X":"0.0", "Y":"0.0", "Orientation":"0.0"}', "홈 포지션으로 복귀");

INSERT INTO tMstScript4CoOperRobot VALUES ('1', 'Loading', "UR",  3, 1, '{"Body":"0, -1.5708, 0, -1.5708, 0, 0"}', "로봇을 다른 위치로 이동 (물체 운반)");
INSERT INTO tMstScript4CoOperRobot VALUES ('1', 'Loading', "UR",  3, 2, '{"Body":"1.5708, -1.5708, 1.5708, -1.5708, 1.5708, 0"}', "로봇을 다른 위치로 이동 (물체 운반)");
INSERT INTO tMstScript4CoOperRobot VALUES ('1', 'Loading', "UR",  3, 3, '{"Body":"-1.5708, -1.5708, -1.5708, -1.5708, -1.5708, 0"}', "로봇을 다른 위치로 이동 (물체 운반)");
INSERT INTO tMstScript4CoOperRobot VALUES ('1', 'Loading', "UR",  3, 4, '{"Body":"0, -1.5708, 0, -1.5708, 0, 0"}', "로봇을 다른 위치로 이동 (물체 운반)");

-- ========================================================================================
--   Table No             : 12
--   Table 명              : tMstToken
--   내  용                : token 호출 Event를 UI화면에 실시간 표시. 
--                          모든 token event를 표시할수도 있고 선택된 token event를 표시도 가능하도록 UI 구성
--   성  격                : Master
--   보존기간                : 영구
--   Record 발생건수(1일)    :
--   Total Record 수      : 5
--   Record size          : 31
--   Total size           : 155 = 5 * 31
--   관리화면 유/무           : 유
--   P.K                  : EqpGroupID, ProcessStatus, ObjectOfCoOperRobot, ScriptID, ScriptSeqNoOfBody
--   관련 Table            : 
--   이 력
--          1.2024-06-16 : 최초 생성
--
-- ========================================================================================
DROP TABLE tMstToken;

CREATE TABLE tMstToken; (
   TokenName              NVARCHAR(50) NOT NULL,    -- 대상설비 (Bottle 반출입기, Stocker, 분석기, 폐기모사)
   SelectedFlag           CHAR(1) default NULL,     -- Loading, Unloading
   TokenDescription      NVARCHAR(256)              -- Token 내용
}  ON [Master];
   
ALTER TABLE tMstToken 
      ADD CONSTRAINT tMstToken_PK PRIMARY KEY (TokenName) ON [MasterIdx];

-- ========================================================================================
--   Table No             : 1
--   Table 명             : tLaboratoryDemandInfo
--   내  용                : 실험의뢰정보를 관리하는 Table
--                          AIMS Controller Or LIMS UI에서 요청
--                         확인*)동일 project no 2번 실험하는 경우 있는지 ?
--
--   성  격               : Process
--   보존기간              : 5년 (순환사용)
--   Record 발생건수(1일)   :
--   Total Record 수      : 300개
--   Record size          : 47
--   Total size           : 180 = 5 * 36
--   관리화면 유/무           : 유
--   P.K                  : UserID, ProjectNo, BottleSeqNoOfDemand
--   관련 Table            : 
--   이 력
--          1. 2024-06-22 : 최초 생성
--
-- ========================================================================================
DROP TABLE tLaboratoryDemandInfo;

CREATE TABLE tLaboratoryDemandInfo (
   UserID                 NVARCHAR(30) NOT NULL,    -- 사용자ID (사번)
   ProjectNo              NVARCHAR(10) NOT NULL,    -- Project No
   BottleDemandTotCount   TINYINT,                  -- Bottle 전체요청수량
   BottleSeqNoOfDemand    TINYINT,                  -- Bottle 전체요청수량에서의 순번
   LiquidCharacter        NVARCHAR(10),             -- 용액종료 (Acid:산, Base:염기, Organic:유기)
   CollectionPosition     NVARCHAR(20),             -- 수집위치
   DemandTime             DATETIME                  -- 요청일시
} ON [Process];

ALTER TABLE tLaboratoryDemandInfo
       ADD  CONSTRAINT tLaboratoryDemandInfo_PK PRIMARY KEY (UserID, ProjectNo, BottleSeqNoOfDemand) ON [ProcessIdx];
ALTER TABLE tLaboratoryDemandInfo 
      ADD CONSTRAINT tLaboratoryDemandInfo_FK FOREIGN KEY (UserID) REFERENCES tMstUser(UserID) ON [ProcessIdx];

      
-- ========================================================================================
--   Table No             : 2
--   Table 명             : tProcBottle
--   내  용                : LIMS Bottle을 관리하는 Table
--                         tMstBottle에서는 Bottle정보가 변경되지 않는 것을 관리하고
--                         tProcBottle에서는 공정진행하면서 정보가 변경되는 것을 별도 Table(tProcBotOper)에서 관리
--
--                         착공일때(LoadComp수신) CurrEqpGroupID, CurrEqpSeqNo Set한다.
--                         완공일때(UnloadComp수신) tMstRoute table에서 Next정보를 얻고, NextEqpGroupID Set한다.
--
--                         1. Position(Bottle 반출입기) : Zone(1자리) + Tower(1자리) + Layer(1자리) + Slot(1자리)
--                            1) Zone -> 실병Zone:'1', 빈병Zone:'2', Bottle 투입Zone:'0'
--                            2) Tower
--                               (1) 실병Zone, 빈병Zone -> 싫험실내 기준 가까운쪽:'1',  싫험실내 기준 먼쪽:'3'  
--                               (2) Bottle 투입Zone -> '0'  
--                            3) Layer
--                               (1) 실병Zone, 빈병Zone -> 최상단:'1',  최하단:'5'  
--                               (2) Bottle 투입Zone -> 상단:'1',  하단:'5'  
--                            4) Slot
--                               (1) 실병Zone, 빈병Zone ->  1 ~ 6
--                               (2) Bottle 투입Zone ->  1 ~ 8  
--                         2. Position(Stocker) : Port(2자리, 세로) + slot(2자리, 가로)
--                         3. Position(분석기) : 0001 ~ 0012까지 spot
--
--
--   성  격               : Process
--   보존기간              : 영구 (순환사용)
--   Record 발생건수(1일)   :
--   Total Record 수      : 300개
--   Record size          : 47
--   Total size           : 180 = 5 * 36
--   관리화면 유/무           : 유
--   P.K                  : BottleID
--   관련 Table            : 
--   이 력
--          1. 2024-06-01 : 최초 생성
--          2. 2024-06-19 : field 추가 (RequestTotCnt, RequestRealCnt, RequestSeqNo, MemberOfBottlePack)
--
-- ========================================================================================
DROP TABLE tProcBottle;

CREATE TABLE tProcBottle (
   BottleID               CHAR(15) NOT NULL,        -- Bottle ID
   -- 현공정에 대한 정의
   CurrEqpGroupID         CHAR(1) NOT NULL,         -- 현재 설비군 ID 
   CurrEqpSeqNo           CHAR(1) NOT NULL,         -- 호기 (1부터 시작)
   CurrOperID             CHAR(1) NOT NULL,         -- 현재 작업 ID
   -- 다음공정에 대한 정의  
   NextEqpGroupID         CHAR(1) NOT NULL,         -- 차기 설비군 ID 
   NextOperID             CHAR(1) NOT NULL,         -- 현재 작업 ID
   -- 빈병일 경우 Null (특히 반출입기)
   ExperimentRequestName  NVARCHAR(10),             -- 실험의뢰자
   CurrLiquid             NVARCHAR(10),             -- 용액종료 (Acid:산, Base:염기, Organic:유기)
   RequestDate            DATETIME,                 -- 요청일시 (YYYYmmdd hhmmss), 초단위 관리 필요, 의뢰단위 구분
   RequestTotCnt          TINYINT,                  -- 작업자 분석의뢰 bottle수량
   RequestRealCnt         TINYINT,                  -- 실제작업할 수량. 의뢰자 또는 관리자가 임의적으로 Bottle 제거한 예외 경우 차감필요
   RequestSeqNo           TINYINT,                  -- 일련번호. 의뢰자가 중간에 임의 제거한 경우 SeqNo 다시 부여하여야 함
                                                    -- RequestRealCnt와 RequestSeqNo 일치할때 반송시작, 작업의뢰단위
   MemberOfBottlePack     TINYINT default 0,        -- Pack 단위로 작업수행. Pack에 첫번째 Bottle 반송이 일어날 경우 나머지 Bottle을 set하여 reserve 한다.
   Position               CHAR(4),                  -- Bottle 반출입기, Stocker에서 위치정보, 분석기에서 위치정보
                                                    -- '0000'인 경우 반출 또는 이동중인 Bottle 
   StartTime              DATETIME NOT NULL,        -- 착공시간
   EndTime                DATETIME,                 -- 완공시간
   DispatchingPriority    TINYINT,                  -- 작업우선순위 (1:가장 낮음, 9:Hot Run)
   EventTime              DATETIME,                 -- Event Time (장비에 입고완료시점)
   PrevLiquid             NVARCHAR(10),             -- 이전 작업에서 용액종료 (산, 염기, 유기)
) ON [Process];

ALTER TABLE tProcBottle
       ADD  CONSTRAINT tProcBottle_PK PRIMARY KEY (BottleID) ON [ProcessIdx];
ALTER TABLE tProcBottle 
      ADD CONSTRAINT tProcBottle_FK FOREIGN KEY (BottleID) REFERENCES tMstEqpGroup(BottleID) ON [ProcessIdx];

-- ========================================================================================
--   Table No             : 3
--   Table 명             : tProcBotOper
--   내  용                : LIMS Bottle에서 작업이력을 관리하는 Table
--                         tMstBottle에서는 Bottle정보가 변경되지 않는 것을 관리하고
--                         tProcBottle에서는 공정진행하면서 정보가 변경되는 것을 별도 Table 관리

--                          재사용을 위하여 Bottle 반출입기에 입고할때(OpCode=5) tHisProcBotOper table 데이터 이동하고, 
--                          기존 Data 삭제한다.
--                          6개월 경과한 Garbage Data 자동 삭제를 한다.
-- 
--   성  격               : Process
--   보존기간              : 영구
--   Record 발생건수(1일)   :
--   Total Record 수      : 5
--   Record size          : 25
--   Total size           : 180 = 5 * 36
--   관리화면 유/무           : 유
--   P.K                  : BottleID, EqpGroupID, OperID, StartTime
--   관련 Table            : 
--   이 력
--          1. 2024-06-01 : 최초 생성
--
-- ========================================================================================
DROP TABLE tProcBotOper;

CREATE TABLE tProcBotOper (
   BottleID               CHAR(15) NOT NULL,        -- Bottle ID
   -- 현공정에 대한 정의
   EqpGroupID             CHAR(1) NOT NULL,         -- 설비군 ID 
   OperID                 CHAR(1) NOT NULL,         -- 작업 ID  
   StartTime              DATETIME NOT NULL,        -- 착공시간
   EndTime                DATETIME,                 -- 완공시간
   DispatchingPriority    TINYINT,                  -- 반송우선순위 (1:가장 낮음, 9:Hot Run)
   Position               CHAR(4)                   -- Bottle 반출입기, Stocker에서 위치정보
) ON [Process];

ALTER TABLE tProcBotOper
      ADD  CONSTRAINT tProcBotOper_PK PRIMARY KEY (BottleID, EqpGroupID, OperID, StartTime) ON [ProcessIdx];

-- ========================================================================================
--   Table No             : 4
--   Table 명             : tChgEqpStatus
--   내  용                : 장비사용시간 관리하는 Table
--                          Bottle 반출입기, Stocker는 설비내 Bottle 항상 있는 상태이므로 의미 없음
--                          분석기, 폐기/모사에 대한 장비상태 관리
--
--                          1일 단위로 tDailyEqpStatus summary data만들고, 
--                          50일 경과된 데이터는 tHisChgEqpStatus table 이동하고 data 삭제한다.
--                          6개월 경과한 Garbage Data 자동 삭제를 한다.
--   성  격               : Process
--   보존기간              : 3년
--   Record 발생건수(1일)   : 
--   Total Record 수      : ??개
--   Record size          : 28
--   Total size           : 180 = 5 * 36
--   관리화면 유/무           : 유
--   P.K                  : EqpGroupID, EqpSeqNo, EqpStatus, StartTime
--   관련 Table            : 
--   이 력
--          1. 2024-06-01 : 최초 생성
--
-- ========================================================================================
DROP TABLE tChgEqpStatus;

CREATE TABLE tChgEqpStatus (
   EqpGroupID             CHAR(1) NOT NULL,         -- 설비군ID
   EqpSeqNo               CHAR(1) NOT NULL,         -- 호기 (1부터 시작)
   EqpStatus              NVARCHAR(10) NOT NULL,    -- 장비상태(Run, Idle, Trouble, Maintenance)
   StartTime              DATETIME NOT NULL,        -- 장비상태 시작시간
   EndTime                DATETIME                  -- 장비상태 종료시간
) ON [Process];

ALTER TABLE tChgEqpStatus
       ADD  CONSTRAINT tChgEqpStatus_PK PRIMARY KEY (EqpGroupID, EqpSeqNo, EqpStatus, StartTime) ON [ProcessIdx];
ALTER TABLE tChgEqpStatus 
      ADD CONSTRAINT tChgEqpStatus_FK FOREIGN KEY (EqpGroupID, EqpSeqNo) REFERENCES tMstEqpGroup(EqpGroupID, EqpSeqNo) ON [ProcessIdx];

-- ========================================================================================
--   Table No             : 5
--   Table 명             : tDailyEqpStatus
--   내  용                : 일일 장비사용시간 관리하는 Table
--                          날짜가 변경될때 자동생성
--
--   성  격               : Process
--   보존기간              : 3년
--   Record 발생건수(1일)   : 1개
--   Total Record 수      : 300개 * 365(일) * 3(년)
--   Record size          : 20
--   Total size           : 180 = 5 * 36
--   관리화면 유/무           : 유
--   P.K                  : EqpGroupID, EqpSeqNo
--   관련 Table            : 
--   이 력
--          1. 2024-06-01 : 최초 생성
--
-- ========================================================================================
DROP TABLE tDailyEqpStatus;

CREATE TABLE tDailyEqpStatus (
   EqpGroupID             CHAR(1) NOT NULL,         -- 설비군ID
   EqpSeqNo               CHAR(1) NOT NULL,         -- 호기 (1부터 시작)
   SummaryDate            DATE NOT NULL,            -- 날짜
   EqpStatus              NVARCHAR(10)  NOT NULL,   -- 장비상태(Run, Idle, Trouble, Maintenance)
   AccumTmByOneDay        TIME                      -- 상태별 누적시간 (EndTime-StartTime, 24시간 넘을수 없다)
) ON [Process];

ALTER TABLE tDailyEqpStatus
       ADD  CONSTRAINT tDailyEqpStatus_PK PRIMARY KEY (EqpGroupID, EqpSeqNo, SummaryDate, EqpStatus) ON [ProcessIdx];
ALTER TABLE tDailyEqpStatus 
      ADD CONSTRAINT tDailyEqpStatus_FK FOREIGN KEY (EqpGroupID, EqpSeqNo) REFERENCES tMstEqpGroup(EqpGroupID, EqpSeqNo) ON [ProcessIdx];
ALTER TABLE tDailyEqpStatus
      ADD CONSTRAINT tDailyEqpStatus_CHK_status CHECK (EqpStatus IN ('Run', 'Idle', 'Trouble', 'Maintenance')) ON [ProcessIdx];
ALTER TABLE tDailyEqpStatus
      ADD CONSTRAINT tDailyEqpStatus_CHK_AccumTmByOneDay CHECK (TIMEDIFF(AccumTmByOneDay, '0000-01-01 00:00:00') <= '24:00:00') ON [ProcessIdx];
   
-- ========================================================================================
--   Table No             : 1
--   Table 명             : tHisProcBotOper
--   내  용                : LIMS Bottle 세정후에 tProcBotOper에서 tHisProcBotOper 이동
--
--   성  격               : Process
--   보존기간              : 영구
--   Record 발생건수(1일)   :
--   Total Record 수      : 5
--   Record size          : 25
--   Total size           : 180 = 5 * 36
--   관리화면 유/무           : 유
--   P.K                  : BottleID, EqpGroupID, OperID, StartTime
--   관련 Table            : 
--   이 력
--          1. 2024-06-01 : 최초 생성
--
-- ========================================================================================
DROP TABLE tHisProcBotOper;

CREATE TABLE tHisProcBotOper (
   BottleID               CHAR(15) NOT NULL,        -- 설비군ID
   EqpGroupID             CHAR(1) NOT NULL,         -- 설비군 ID 
   OperID                 CHAR(1) NOT NULL,         -- 작업 ID  
   StartTime              DATETIME NOT NULL,        -- 착공시간
   EndTime                DATETIME,                 -- 완공시간
   DispatchingPriority    TINYINT,                  -- 반송우선순위 (1:가장 낮음, 9:Hot Run)
   Position               CHAR(4)                   -- Bottle 반출입기, Stocker에서 위치정보
) ON [History];

ALTER TABLE tHisProcBotOper
      ADD  CONSTRAINT tHisProcBotOper_PK PRIMARY KEY (BottleID, EqpGroupID, OperID, StartTime) ON [HistoryIdx];
      
-- ========================================================================================
--   Table No             : 2
--   Table 명             : tHisChgEqpStatus
--   내  용                : LIMS Bottle 세정후에 tChgEqpStatus에서 tHisChgEqpStatus 이동
--
--   성  격               : Process
--   보존기간              : 영구
--   Record 발생건수(1일)   :
--   Total Record 수      : 5
--   Record size          : 25
--   Total size           : 180 = 5 * 36
--   관리화면 유/무           : 유
--   P.K                  : EqpGroupID, EqpSeqNo, EqpStatus,StartTime
--   관련 Table            : 
--   이 력
--          1. 2024-06-01 : 최초 생성
--
-- ========================================================================================
DROP TABLE tHisChgEqpStatus;

CREATE TABLE tHisChgEqpStatus (
   EqpGroupID             CHAR(1) NOT NULL,         -- 설비군ID
   EqpSeqNo               CHAR(1) NOT NULL,         -- 호기 (1부터 시작)
   EqpStatus              NVARCHAR(10),             -- 장비상태(Run, Idle, Trouble, Maintenance)
   StartTime              DATETIME,                 -- 시작시간
   EndTime                DATETIME                  -- 종료시간
) ON [History];

ALTER TABLE tHisChgEqpStatus
      ADD  CONSTRAINT tHisChgEqpStatus_PK PRIMARY KEY (EqpGroupID, EqpSeqNo, EqpStatus,StartTime) ON [HistoryIdx];    