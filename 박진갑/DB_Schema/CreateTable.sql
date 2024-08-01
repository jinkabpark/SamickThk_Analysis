

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
--          No.   Table 명                   Size
--         ----  -----------------         --------
--          1   tMstUser                   	1 K
--          2   tMstEqpGroup               	1 K
--          3   tMstEqp                    	1 K
--          4   tMstOperation              	1 K
--          5   tMstBottle                 	1 K
--          6   tMstRouteOper              	1 K
--          7   tMstRecipe4Analyzer     	1 K
--          7   tMstScript4Manipulator     	1 K
--          8   tMstScript4UR              	1 K
--          9   tMstScript4CoOperRobot     	1 K
--          10  tMstScriptID4CoOperRobot   	1 K
--          11  tMstScriptBody4CoOperRobot 	1 K
--          12  tMstTopic                  	1 K
-- ============================================================================
-- Table Space 명   : Process
-- 내 용            : 공정관련 table을 관리하는 table space
--
-- 관련 Master Table
--          No.    Table 명                  Size
--         ----  ------------------------  ------------
--          1   tLaboratoryDemandInfo
--          2   tProcBottle
--          3   tProcBotOper
--          4   tChgEqpStatus
--          5   tDailyEqpStatus
--          6   tBottleInfoOfHoleAtInOutBottle
--          7   tBottleInfoOfHoleAtStocker
--          8   tBottleInfoOfHoleAtAnalyzer
--          9   tBottleInfoOfHoleAtMOMA
--          10  tProcScriptID4CoOperRobot
--          11  tProcSqlError
-- ============================================================================
-- Table Space 명   : History
-- 내 용            : 공정관련 table을 관리하는 table space
--
-- 관련 Master Table
--          No.    Table 명             Size
--         ----  --------------------  ------------
--          1   tHisProcBotOper
--          2   tHisChgEqpStatus
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
   UserID                   NVARCHAR(30) NOT NULL,  -- 사용자ID (사번)
   UserName                 NVARCHAR(10),           -- 사용자ID (사번)
   Password                 NVARCHAR(16),           -- Password, 패스워드 속성
   ClassID                  TINYINT,                -- 사용자 권한 등급 (1:MONITORING, 3:OP, 5:MASTER, 9:DEV)
   UpdateTime               DATETIME
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
--          2.2024-06-14 : field 추가 (NodeName)
--
-- ========================================================================================
DROP TABLE tMstEqpGroup;

CREATE TABLE tMstEqpGroup (
   EqpGroupID               CHAR(1) NOT NULL,       -- 설비군ID
   NodeName                 NVARCHAR(30)            -- DDS사용하는 Node명
   EqpGroupName             NVARCHAR(30)            -- 설비명
) ON [Master];

ALTER TABLE tMstEqpGroup
      ADD CONSTRAINT tMstEqpGroup_PK PRIMARY KEY (EqpGroupID) ON [MasterIdx];

INSERT INTO tMstEqpGroup VALUES ('0', 'Dummy', N'Dummy');          -- Bottle 잡지않고 이동하는 경우 사
INSERT INTO tMstEqpGroup VALUES ('1', 'InOutBottle', N'반출입기');
INSERT INTO tMstEqpGroup VALUES ('2', 'Stocker', N'Stocker');      -- Stocker #1호기
INSERT INTO tMstEqpGroup VALUES ('3', 'Analyzer', N'분석기');
INSERT INTO tMstEqpGroup VALUES ('4', 'CleaningScrap', N'폐기설비');
INSERT INTO tMstEqpGroup VALUES ('5', 'MOMA', N'이동형협업로봇');



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
   EqpGroupID               CHAR(1) NOT NULL,       -- 설비군ID
   EqpSeqNo                 TINYINT NOT NULL,       -- 호기 (1부터 시작)
   EqpName                  NVARCHAR(30),           -- 설비명
   CapacityOfHole           TINYINT,                -- 분석기 설비 hole(병을 처리할수 있는) 케파
   CapacityOfEmptyZone      TINYINT,                -- 반출입기 설비 hole(병을 처리할수 있는) 케파
   CapacityOfFilledZone     TINYINT,                -- 반출입기 설비 hole(병을 처리할수 있는) 케파
   CapacityOfLeftZone       TINYINT,                -- Stocker 설비 hole(병을 처리할수 있는) 케파
   CapacityOfRightZone      TINYINT,                -- Stocker 설비 hole(병을 처리할수 있는) 케파
   EqpStatus                NVARCHAR(10),           -- 장비상태 (PowerOn, PowerOff, Reserve, Ready, Run, Idle, Pause, Disconnect, Trouble:통신불가, Maintenance, Waiting)
                                                    -- 1) 반출입기 상태 : PowerOn, Trouble, Maintenance
                                                    -- 2) Stocker 상태 : PowerOn, Trouble, Maintenance
                                                    -- 3) 분석기 상태 : PowerOn, Trouble, Maintenance, Reserve, Run, Waiting, Idle
                                                    -- 4) 폐기/모사 상태 : PowerOn, Trouble, Maintenance
                                                    -- 5) MOMA 상태 : PowerOn, Trouble, Maintenance, Reserve, Ready, Run, Idle
                                                    -- Ready는 MOMA에서만 사용. MOMA 장비앞에 도착하여 장비와 정렬 맞춘후(PIO통신을 이용) 작업준비가 완료된 상태
   ProcessStatus            NVARCHAR(12),           -- 진행 상태(LoadReq, LoadComp, UnLoadReq, UnLoadComp, Reserve), 반출입기 이외 장비에서 사용
                                                    -- stocker, 분석기, MOMA에서는 port 개념없음.
                                                    --     LoadReq, UnLoadReq event가 장비단위로 발생됨. Dispatcher에게 반송정보 전달을 위해 관리함.
                                                    --     LoadComp, UnLoadComp event가 장비아닌 bottle단위로 발생됨
                                                    -- 따라서, stocker, 분석기, MOMA에서는 장비상태 변경이 불필요
   // 반출입기에서는 Process status를 port별로 관리
   LoadPort_1               NVARCHAR(12),           -- 진행 상태(LoadReq, LoadComp, UnLoadReq, UnLoadComp, Reserve)
   LoadPort_2               NVARCHAR(12),           -- 진행 상태(LoadReq, LoadComp, UnLoadReq, UnLoadComp, Reserve)
   UnloadPort_1             NVARCHAR(12),           -- 진행 상태(LoadReq, LoadComp, UnLoadReq, UnLoadComp, Reserve)
   UnloadPort_2             NVARCHAR(12),           -- 진행 상태(LoadReq, LoadComp, UnLoadReq, UnLoadComp, Reserve)
   EventTime                DATETIME,               -- Event Time
   EqpTimeWriteLog          INT default 0           -- 장비 내부 LOG 저장 시간
) ON [Master];

ALTER TABLE tMstEqp
      ADD CONSTRAINT tMstEqp_PK PRIMARY KEY (EqpGroupID, EqpSeqNo) ON [MasterIdx];
ALTER TABLE tMstEqp
      ADD CONSTRAINT tMstEqp_FK_EqpGroupID FOREIGN KEY (EqpGroupID) REFERENCES tMstEqpGroup(EqpGroupID) ON [MasterIdx];
ALTER TABLE tMstEqp
      ADD CONSTRAINT tMstEqp_CHK CHECK (EqpStatus in ("PowerOn", "PowerOff", "Run", "Waiting", "Idle", "Trouble", "Maintenance")) ON [MasterIdx];

INSERT INTO tMstEqp VALUES ('1', 1, N'반출입기', 90, "Idle", "LoadReq", null, null, null, null);
INSERT INTO tMstEqp VALUES ('2', 1, N'Stocker', 96, "Idle", "LoadReq", null, null, null, null);      -- Stocker #1호기
INSERT INTO tMstEqp VALUES ('3', 1, N'분석기 1호기', 12, "Idle", "LoadReq", null, null, null, null);
INSERT INTO tMstEqp VALUES ('3', 2, N'분석기 2호기', 12, "Idle", "LoadReq", null, null, null, null);
INSERT INTO tMstEqp VALUES ('3', 3, N'분석기 3호기', 12, "Idle", "LoadReq", null, null, null, null);
INSERT INTO tMstEqp VALUES ('4', 1, N'폐기설비', 1, "Idle", "LoadReq", null, null, null, null);
INSERT INTO tMstEqp VALUES ('5', 1, N'이동형협업로봇', 12, "Idle", "LoadComp", null, null, null, null);


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
   EqpGroupID               CHAR(1) NOT NULL,       -- 설비군 ID
   --OperGroupID            CHAR(1) NOT NULL,       -- Operation Group
   OperID                   CHAR(1) NOT NULL,       -- 작업 ID
   OperName                 NVARCHAR(40)            -- Operation Description
) ON [Master];

ALTER TABLE tMstOperation
      ADD CONSTRAINT tMstOperation_PK PRIMARY KEY (EqpTypeID, OperID) ON [MasterIdx];
ALTER TABLE tMstOperation
      ADD CONSTRAINT tMstOperation_FK_EqpGroupID FOREIGN KEY (EqpGroupID) REFERENCES tMstEqpGroup(EqpGroupID) ON [MasterIdx];

INSERT INTO tMstOperation VALUES ('1', '1', N'공병Zone 대기');      -- 세정후 공병투입(세정후 재사용을 위하여 투입)
INSERT INTO tMstOperation VALUES ('1', '2', N'시료채취중');              -- 작업의뢰자가 시료채취
INSERT INTO tMstOperation VALUES ('1', '3', N'실병Zone 대기');          -- 시료채취후 실병투입

INSERT INTO tMstOperation VALUES ('2', '1', N'분석 작업중');
INSERT INTO tMstOperation VALUES ('3', '1', N'분석전 Stocker 입고');         --
INSERT INTO tMstOperation VALUES ('3', '2', N'분석후 Stocker 입고');         --
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
   BottleID                 CHAR(10) NOT NULL,      -- Bottle ID
   Creation                 DATETIME,               -- 생성일
   Termination              DATETIME                -- 폐기일
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
   RouteID                  CHAR(5) NOT NULL,       -- Route ID
   -- 현공정에 대한 정의
   CurrEqpGroupID           CHAR(1) NOT NULL,       -- 현재 설비군 ID
   CurrOperID               CHAR(1) NOT NULL,       -- 현재 작업 ID
   -- 다음공정에 대한 정의
   NextEqpGroupID           CHAR(1) NOT NULL,       -- 차기 설비군 ID
   NextOperID               CHAR(1) NOT NULL        -- 차기 작업 ID
) ON [Master];

ALTER TABLE tMstRouteOper
       ADD CONSTRAINT tMstRoute_PK PRIMARY KEY (RouteID, CurrEqpGroupID, CurrOperID, NextEqpGroupID) ON [MasterIdx];

INSERT INTO tMstRouteOper VALUES ('R1', '0', '0', '1', '1');
INSERT INTO tMstRouteOper VALUES ('R1', '1', '1', '1', '2');     -- 공병Zone 대기, 작업자가 시료채취를 위해 반출요청
INSERT INTO tMstRouteOper VALUES ('R1', '1', '2', '1', '3');     -- 시료채취중, 시료채취
INSERT INTO tMstRouteOper VALUES ('R1', '1', '3', '3', '1');     -- 실병Zone 대기, 작업자가 시료채취후 투입

INSERT INTO tMstRouteOper VALUES ('R1', '3', '1', '2', '1');     -- 분석전 Stocker 입고
INSERT INTO tMstRouteOper VALUES ('R1', '2', '1', '3', '2');     -- 분석 작업중
INSERT INTO tMstRouteOper VALUES ('R1', '3', '2', '4', '1');     -- 분석후 Stocker 입고
INSERT INTO tMstRouteOper VALUES ('R1', '4', '1', '1', '1');     -- 폐기설비 작업중

-- ========================================================================================
--   Table No             : 7
--   Table 명             : tMstRecipe4Analyzer
--   내  용                : 분석기에 Recipe 관리하는 Table
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
DROP TABLE tMstRecipe4Analyzer;

CREATE TABLE tMstRecipe4Analyzer (
   RecipeID                 CHAR(5) NOT NULL,       -- Recipe ID
   Description              NVARCHAR(30)            -- Description
) ON [Master];

ALTER TABLE tMstRecipe4Analyzer
       ADD CONSTRAINT tMstRecipe4Analyzer_PK PRIMARY KEY (RecipeID) ON [MasterIdx];

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
   FmEqpGroupID             CHAR(1) NOT NULL,       -- 이동시작설비
   ToEqpGroupID             CHAR(1) NOT NULL,       -- 이동종료설비
   ScriptSeqNo              INT,                    -- Script Sequence No
   X_Coordinate             FLOAT,                  -- X 좌표
   Y_Coordinate             FLOAT,                  -- Y 좌표
   Orientation              FLOAT                   -- 방향
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
   EqpGroupID               CHAR(1) NOT NULL,       -- 이동시작설비
   ProcessStatus            NVARCHAR(10) NOT NULL,  -- Loading, Unloading
   ScriptSeqNo              INT,                    -- Script Sequence No
   ScriptBody               NVARCHAR(256)           -- Script 내용
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
   FmEqpGroupID             CHAR(1) NOT NULL,       -- 이동시작설비
   ToEqpGroupID             CHAR(1) NOT NULL,       -- 이동종료설비
   ScriptSeqNo              INT,                    -- Script Sequence No
   TgtObject                NVARCHAR(10),           -- Object (UR, MIR, Gripper, Vision), 즉 Table명
   BodyOfJsonType           TEXT,                   -- 장치별 JSON Type Script Body
   Description              TEXT                    -- Script에 대한 내용기술
   --X_Coordinate_MIR       FLOAT,                  -- X 좌표
   --Y_Coordinate_MIR       FLOAT,                  -- Y 좌표
   --Orientation_MIR        FLOAT,                  -- 방향
   --ScriptBody_UR          NVARCHAR(256)           -- Script 내용
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
--   P.K                  : SequenceNum
--   관련 Table            :
--   이 력
--          1.2024-06-16 : 최초 생성
--
-- ========================================================================================
DROP TABLE tMstScriptID4CoOperRobot;

CREATE TABLE tMstScriptID4CoOperRobot; (
   SequenceNum              TINYINT  NOT NULL,      -- 분석실에서 사용하는 robot script 일련번호
   EqpGroupID               CHAR(1) NOT NULL,       -- 대상설비 (Bottle 반출입기, Stocker, 분석기, 폐기모사)
   ProcessStatus            NVARCHAR(10) NOT NULL,  -- Loading, Unloading
   ObjectOfCoOperRobot      NVARCHAR(10) NOT NULL,  -- 이동형 협업로봇 Object (UR, MIR, Gripper, Vision), 즉 Device명
   ScriptID                 INT NOT NULL,           -- Script ID No
   Activation               CHAR(1),                -- 1:활성화, 0:비활성화
   ScriptDescription        NVARCHAR(256)           -- Script 내용
}  ON [Master];

ALTER TABLE tMstScriptID4CoOperRobot
      ADD CONSTRAINT tMstScriptID4CoOperRobot_PK PRIMARY KEY (SequenceNum) ON [MasterIdx];

ALTER TABLE tMstScriptID4CoOperRobot
      ADD CONSTRAINT tMstScriptID4CoOperRobot_CHK CHECK (Activation in ('0', '1')) ON [MasterIdx];

INSERT INTO tMstScriptID4CoOperRobot VALUES (1, '1', 'Loading', "UR", 1, '1', 'UR Loading시 동작정의');                    --
INSERT INTO tMstScriptID4CoOperRobot VALUES (2, '1', 'Loading', "UR", 2, '0', 'UR Loading시 동작 예비 1');                    --

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
   EqpGroupID               CHAR(1) NOT NULL,       -- 대상설비 (Bottle 반출입기, Stocker, 분석기, 폐기모사)
   ProcessStatus            NVARCHAR(10) NOT NULL,  -- Loading, Unloading
   ObjectOfCoOperRobot      NVARCHAR(10) NOT NULL,  -- 이동형 협업로봇 Object (UR, MIR, Gripper, Vision), 즉 Device명
   ScriptID                 INT NOT NULL,           -- Script ID No
   ScriptSeqNoOfBody        INT NOT NULL,           -- Script Body의 Sequence No
   ScriptBody               NVARCHAR(256),          -- Script 구분동작
   ScriptDescription        NVARCHAR(256)           -- Script 내용
}  ON [Master];

ALTER TABLE tMstScriptBody4CoOperRobot
      ADD CONSTRAINT tMstScriptBody4CoOperRobot_PK PRIMARY KEY (EqpGroupID, ProcessStatus, ObjectOfCoOperRobot, ScriptID, ScriptSeqNoOfBody) ON [MasterIdx];

ALTER TABLE tMstScriptID4CoOperRobot
      ADD CONSTRAINT tMstScriptBody4CoOperRobot_FK_EqpGroupID_ProcessStatus FOREIGN KEY (EqpGroupID, ProcessStatus, ObjectOfCoOperRobot, ScriptID, ScriptSeqNoOfBody)
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
--   Table 명              : tMstTopic
--   내  용                : token 호출 Event를 UI화면에 실시간 표시.
--                          모든 token event를 표시할수도 있고 선택된 token event를 표시도 가능하도록 UI 구성
--   성  격                : Master
--   보존기간                : 영구
--   Record 발생건수(1일)    :
--   Total Record 수      : 5
--   Record size          : 31
--   Total size           : 155 = 5 * 31
--   관리화면 유/무           : 유
--   P.K                  : TopicName
--   관련 Table            :
--   이 력
--          1.2024-06-16 : 최초 생성
--
-- ========================================================================================
DROP TABLE tMstTopic;

CREATE TABLE tMstTopic; (
   PublisherEqpGroupID      CHAR(1) NOT NULL,       -- Publisher 설비군ID
   TopicFullName            NVARCHAR(50) NOT NULL,  -- /InOutBottle/ReportChangedEqpStatus
   TopicOnlyName            NVARCHAR(50) NOT NULL,  -- ReportChangedEqpStatus
   SubscriberEqpGroupID     CHAR(1) NOT NULL,       -- Subscriber 설비군ID
   SelectedFlag             CHAR(1) default NULL,   -- 선택적으로 보고싶을때 사용('O':화면표시, 'X':화면 표시하지 않음)
   TopicDescription         NVARCHAR(256)           -- Token 내용
}  ON [Master];

ALTER TABLE tMstTopic
      ADD CONSTRAINT tMstTopic_PK PRIMARY KEY (PublisherEqpGroupID, TopicFullName) ON [MasterIdx];

-- tMstSubscriberEqpGroup 테이블 생성
CREATE TABLE tMstSubscriberEqpGroup (
    EqpGroupID CHAR(1) NOT NULL                   -- Subscriber 설비군ID
);
ALTER TABLE tMstTopic
      ADD CONSTRAINT tMstTopic_PK PRIMARY KEY (EqpGroupID) ON [MasterIdx];

-- tMstTopicSubscriber 테이블 생성 (토픽과 구독자 그룹 간의 관계)
CREATE TABLE tMstTopicSubscriber (
    id INT AUTO_INCREMENT PRIMARY KEY,
    PublisherEqpGroupID CHAR(1) NOT NULL,
    TopicFullName NVARCHAR(50) NOT NULL,
    SubscriberEqpGroupID CHAR(1) NOT NULL,
    FOREIGN KEY (PublisherEqpGroupID, TopicFullName) REFERENCES tMstTopic(PublisherEqpGroupID, TopicFullName),
    FOREIGN KEY (SubscriberEqpGroupID) REFERENCES tMstSubscriberEqpGroup(EqpGroupID)
);

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
--   P.K                  : UserID, ProjectNum, BottleSeqNoOfDemand
--   관련 Table            :
--   이 력
--          1. 2024-06-22 : 최초 생성
--          2. 2024-07-06 : field명 변경. tProcBottle table 통일 (DemandTime -> RequestDate)
--
-- ========================================================================================
DROP TABLE tLaboratoryDemandInfo;

CREATE TABLE tLaboratoryDemandInfo (
   UserID                   NVARCHAR(30) NOT NULL,  -- 사용자ID (사번)
   ProjectNum               NVARCHAR(10) NOT NULL,  -- Project Num
   BottleDemandTotCount     TINYINT,                -- Bottle 전체요청수량
   BottleSeqNoOfDemand      TINYINT,                -- Bottle 전체요청수량에서의 순번
   LiquidCharacter          NVARCHAR(10),           -- 용액종료 (Acid:산, Base:염기, Organic:유기)
   CollectionPosition       NVARCHAR(20),           -- 수집위치
   RequestDate              DATETIME                -- 요청일시 (Pack ID로 사용)
} ON [Process];

ALTER TABLE tLaboratoryDemandInfo
       ADD  CONSTRAINT tLaboratoryDemandInfo_PK PRIMARY KEY (UserID, ProjectNum, BottleSeqNoOfDemand) ON [ProcessIdx];
ALTER TABLE tLaboratoryDemandInfo
      ADD CONSTRAINT tLaboratoryDemandInfo_FK_UserID FOREIGN KEY (UserID) REFERENCES tMstUser(UserID) ON [ProcessIdx];


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
--                         2. Position(Stocker) : 좌우 1자리(Left:1,Right:2) + 0 + + slot 1자리(가로:1~8) + Port 1자리(세로:1~6)
--                         3. Position(분석기) : 0001 ~ 0012까지 spot
--                         4. MOMA : 24개 --> 장비에서 받는것 12, 장비에 적재하는것 12개 ==> 왜? 이렇게 운영하는지. 12개 안되나 ?
--                              - 가로 2자리(01~12), 세로 2자리(1 ~ 2)
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
--          3. 2024-07-06 : field 추가 (AnalyzerCompletedTm)
--                          field 추가, 데이터 관리 편이성위하여 추가함 (PackID)
--                          pack id를 ProjectNum or RequestDate 사용.
--                          ProjectNum unique하면 ProjectNum 사용, unique하지 않으면 RequestDate 사용, 또는 2개 Merge해서 사용
--          4. 2024-07-06 : field 추가 (RecipeID)
--
-- ========================================================================================
DROP TABLE tProcBottle;

CREATE TABLE tProcBottle (
   BottleID                 CHAR(15) NOT NULL,      -- Bottle ID
   -- 현공정에 대한 정의
   CurrEqpGroupID           CHAR(1) NOT NULL,       -- 현재 설비군 ID
   CurrEqpSeqNo             CHAR(1) NOT NULL,       -- 호기 (1부터 시작)
   CurrOperID               CHAR(1) NOT NULL,       -- 현재 작업 ID
   -- 다음공정에 대한 정의
   NextEqpGroupID           CHAR(1) NOT NULL,       -- 차기 설비군 ID
   NextOperID               CHAR(1) NOT NULL,       -- 현재 작업 ID
   --
   ProjectNum               NVARCHAR(10),           -- Project Num, 빈병일 경우 Null (특히 반출입기)
   PackID                   NVARCHAR(10),           -- Project No or RequestDate or Project No+RequestDate
   RecipeID                 CHAR(5) NOT NULL,       -- 분석기 Recipe ID
   AnalyzerCompletedTm      DATETIME,               -- 실험분석완료 시간
   JudgeLimitTm             DATETIME,               -- 실험분석완료후 지정된 시간 경과후, 분석완료후 작업의뢰자 응답이 없는 경우 자동 폐기 처리
   JudgeOfResearcher        NVARCHAR(10),           -- 실험의뢰자 판단. (Discard, Cleaning)
   ExperimentRequestID      NVARCHAR(10),           -- 실험의뢰자 ID
   CurrLiquid               NVARCHAR(10),           -- 용액종료 (Acid:산, Base:염기, Organic:유기)
   RequestDate              DATETIME,               -- 요청의뢰일시 (YYYYmmdd hhmmss), 초단위 관리 필요, 의뢰단위 구분
                                                    -- AIMS 의뢰사간정보 Or AIMS에서 수신한 시간 Or LIMS UI에서 의뢰요청시각
                                                    -- tLaboratoryDemandInfo table의 RequestDate
                                                    -- Pack ID로 사용
   RequestTotCnt            TINYINT,                -- 작업자 분석의뢰 bottle수량
   RequestRealCnt           TINYINT,                -- 실제작업할 수량. 의뢰자 또는 관리자가 임의적으로 Bottle 제거한 예외 경우 차감필요
                                                    -- 처음값은 RequestTotCnt 일치
                                                    -- Bottle 폐기, Bottle split 고려
                                                    -- Lot Split, Lot 폐기시 RequestDate(Pack ID), RequestTotCnt, RequestRealCnt를 수정
   RequestSeqNo             TINYINT,                -- 일련번호. 의뢰자가 중간에 임의 제거한 경우 SeqNo 다시 부여하여야 함
                                                    -- RequestRealCnt와 RequestSeqNo 일치할때 반송시작, 작업의뢰단위
   MemberOfBottlePack       TINYINT default 0,      -- Pack 단위로 작업수행. Pack에 첫번째 Bottle 반송이 일어날 경우 나머지 Bottle을 set하여 reserve 한다.
   --Position                 CHAR(4),                -- Bottle 반출입기, Stocker에서 위치정보, 분석기에서 위치정보
                                                    -- '0000'인 경우 반출 또는 이동중인 Bottle
   StartTime                DATETIME,               -- 착공시간
   EndTime                  DATETIME,               -- 완공시간
   DispatchingPriority      TINYINT,                -- 작업우선순위 (1:가장 낮음, 9:Hot Run)
   EventTime                DATETIME,               -- Event Time (장비에 입고완료시점)
   PrevLiquid               NVARCHAR(10),           -- 이전 작업에서 용액종료 (산, 염기, 유기)
) ON [Process];

ALTER TABLE tProcBottle
       ADD  CONSTRAINT tProcBottle_PK PRIMARY KEY (BottleID) ON [ProcessIdx];
ALTER TABLE tProcBottle
      ADD CONSTRAINT tProcBottle_FK_BottleID FOREIGN KEY (BottleID) REFERENCES tMstEqpGroup(BottleID) ON [ProcessIdx];
ALTER TABLE tProcBottle
      ADD CONSTRAINT tProcBottle_FK_RecipeID FOREIGN KEY (RecipeID) REFERENCES tMstRecipe4Analyzer(RecipeID) ON [ProcessIdx];

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
   BottleID                 CHAR(15) NOT NULL,      -- Bottle ID
   -- 현공정에 대한 정의
   EqpGroupID               CHAR(1) NOT NULL,       -- 설비군 ID
   OperID                   CHAR(1) NOT NULL,       -- 작업 ID
   StartTime                DATETIME NOT NULL,      -- 착공시간
   EndTime                  DATETIME,               -- 완공시간
   DispatchingPriority      TINYINT,                -- 반송우선순위 (1:가장 낮음, 9:Hot Run)
   Position                 CHAR(4)                 -- Bottle 반출입기, Stocker에서 위치정보
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
   EqpGroupID               CHAR(1) NOT NULL,       -- 설비군ID
   EqpSeqNo                 CHAR(1) NOT NULL,       -- 호기 (1부터 시작)
   EqpStatus                NVARCHAR(10) NOT NULL,  -- 장비상태(Run, Idle, Trouble, Maintenance)
   StartTime                DATETIME NOT NULL,      -- 장비상태 시작시간
   EndTime                  DATETIME                -- 장비상태 종료시간
) ON [Process];

ALTER TABLE tChgEqpStatus
       ADD  CONSTRAINT tChgEqpStatus_PK PRIMARY KEY (EqpGroupID, EqpSeqNo, EqpStatus, StartTime) ON [ProcessIdx];
ALTER TABLE tChgEqpStatus
      ADD CONSTRAINT tChgEqpStatus_FK_EqpGroupIDEqpSeqNo FOREIGN KEY (EqpGroupID, EqpSeqNo) REFERENCES tMstEqpGroup(EqpGroupID, EqpSeqNo) ON [ProcessIdx];

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
   EqpGroupID               CHAR(1) NOT NULL,       -- 설비군ID
   EqpSeqNo                 CHAR(1) NOT NULL,       -- 호기 (1부터 시작)
   SummaryDate              DATE NOT NULL,          -- 날짜
   EqpStatus                NVARCHAR(10)  NOT NULL, -- 장비상태(Run, Idle, Trouble, Maintenance)
   AccumTmByOneDay          TIME                    -- 상태별 누적시간 (EndTime-StartTime, 24시간 넘을수 없다)
) ON [Process];

ALTER TABLE tDailyEqpStatus
       ADD  CONSTRAINT tDailyEqpStatus_PK PRIMARY KEY (EqpGroupID, EqpSeqNo, SummaryDate, EqpStatus) ON [ProcessIdx];
ALTER TABLE tDailyEqpStatus
      ADD CONSTRAINT tDailyEqpStatus_FK_EqpGroupID_EqpSeqNo FOREIGN KEY (EqpGroupID, EqpSeqNo) REFERENCES tMstEqpGroup(EqpGroupID, EqpSeqNo) ON [ProcessIdx];
ALTER TABLE tDailyEqpStatus
      ADD CONSTRAINT tDailyEqpStatus_CHK_status CHECK (EqpStatus IN ('Run', 'Idle', 'Trouble', 'Maintenance')) ON [ProcessIdx];
ALTER TABLE tDailyEqpStatus
      ADD CONSTRAINT tDailyEqpStatus_CHK_AccumTmByOneDay CHECK (TIMEDIFF(AccumTmByOneDay, '0000-01-01 00:00:00') <= '24:00:00') ON [ProcessIdx];

-- ========================================================================================
--   Table No             : 6
--   Table 명             : tBottleInfoOfHoleAtInOutBottle
--   내  용                : 반출입기에서 hole position별 Bottle 정보를 관리한다
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
--                          좌우 48개 hole 존재. hole갯수만큼 recode를 사전에 만들고 프로그램에서는 update만 수행
--
--   성  격               : Process
--   보존기간              : 무관
--   Record 발생건수(1일)   : -
--   Total Record 수      : 96개
--   Record size          : 20
--   Total size           : 180 = 5 * 36
--   관리화면 유/무           : 유
--   P.K                  : EqpSeqNo, Position
--   관련 Table            :
--   이 력
--          1. 2024-07-07 : 최초 생성
--          2. 2024-07-14 : field 추가 (AllocationPriority, EventTime), bottle 투입하는 방법처리하기 위함
--             1) Position 기준으로 sorting 하는 방법
--             2) EventTime 기준으로 sorting 하는 방법 (순서적으로 순환하면서 hole 사용하는 방안)
--             3) AllocationPriority 기준으로 sorting 하는 방법. (hole 우선순위 정해서 사용하는 방안)
--
-- ========================================================================================
DROP TABLE tBottleInfoOfHoleAtInOutBottle;

CREATE TABLE tBottleInfoOfHoleAtInOutBottle (
   EqpSeqNo                 CHAR(1) NOT NULL,       -- 호기 (1부터 시작)
   ZoneName                 CHAR(7),                -- 좌:Empty, 우:Filled
   Position                 CHAR(4) NOT NULL,       -- Stocker에서 위치정보
   UsageFlag                CHAR(1) default 'O',    -- 'O':사용가능, 'X':사용불가
   AllocationPriority       TINYINT default 1,      -- 1 부터 시작
   EventTime                DATETIME,               -- Event Time
   BottleID                 CHAR(15)                -- Bottle ID
) ON [Process];

ALTER TABLE tBottleInfoOfHoleAtInOutBottle
       ADD  CONSTRAINT tBottleInfoOfHoleAtInOutBottle_PK PRIMARY KEY (EqpSeqNo, Position) ON [ProcessIdx];

-- ========================================================================================
--   Table No             : 7
--   Table 명             : tBottleInfoOfHoleAtStocker
--   내  용                : Analyzer에서 hole position별 Bottle 정보를 관리한다
--                          좌우 48개 hole 존재. hole갯수만큼 recode를 사전에 만들고 프로그램에서는 update만 수행
--
--                          - 좌우 1자리(Left:1,Right:2) + 0 + + slot 1자리(가로:1~8) + Port 1자리(세로:1~6)
--   성  격               : Process
--   보존기간              : 무관
--   Record 발생건수(1일)   : -
--   Total Record 수      : 96개
--   Record size          : 20
--   Total size           : 180 = 5 * 36
--   관리화면 유/무           : 유
--   P.K                  : EqpSeqNo, Position
--   관련 Table            :
--   이 력
--          1. 2024-07-07 : 최초 생성
--          2. 2024-07-14 : field 추가 (AllocationPriority, EventTime), bottle 투입하는 방법처리하기 위함
--             1) Position 기준으로 sorting 하는 방법
--             2) EventTime 기준으로 sorting 하는 방법 (순서적으로 순환하면서 hole 사용하는 방안)
--             3) AllocationPriority 기준으로 sorting 하는 방법. (hole 우선순위 정해서 사용하는 방안)
--
-- ========================================================================================
DROP TABLE tBottleInfoOfHoleAtStocker;

CREATE TABLE tBottleInfoOfHoleAtStocker (
   EqpSeqNo                 CHAR(1) NOT NULL,       -- 호기 (1부터 시작)
   ZoneName                 CHAR(5),                -- 좌:Left, 우:Right
   Position                 CHAR(4) NOT NULL,       -- Stocker에서 위치정보
   UsageFlag                CHAR(1) default 'O',    -- 'O':사용가능, 'X':사용불가
   AllocationPriority       TINYINT default 1,      -- 1 부터 시작
   EventTime                DATETIME,               -- Event Time
   BottleID                 CHAR(15)                -- Bottle ID
) ON [Process];

ALTER TABLE tBottleInfoOfHoleAtStocker
       ADD  CONSTRAINT tBottleInfoOfHoleAtStocker_PK PRIMARY KEY (EqpSeqNo, Position) ON [ProcessIdx];

-- 좌측 48개 (8*6)
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1011', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1012', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1013', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1014', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1015', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1016', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1021', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1022', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1023', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1024', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1025', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1026', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1031', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1032', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1033', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1034', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1035', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1036', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1041', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1042', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1043', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1044', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1045', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1046', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1051', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1052', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1053', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1054', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1055', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1056', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1061', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1062', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1063', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1064', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1065', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1066', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1071', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1072', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1073', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1074', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1075', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1076', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1081', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1082', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1083', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1084', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1085', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('1', 'Left', '1086', 'O', null);

-- 우측 48개 (8*6)
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2011', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2012', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2013', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2014', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2015', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2016', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2021', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2022', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2023', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2024', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2025', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2026', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2031', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2032', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2033', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2034', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2035', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2036', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2041', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2042', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2043', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2044', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2045', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2046', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2051', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2052', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2053', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2054', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2055', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2056', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2061', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2062', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2063', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2064', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2065', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2066', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2071', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2072', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2073', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2074', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2075', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2076', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2081', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2082', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2083', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2084', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2085', 'O', null);
INSERT INTO tBottleInfoOfHoleAtStocker VALUES ('2', 'Right', '2086', 'O', null);

-- ========================================================================================
--   Table No             : 8
--   Table 명             : tBottleInfoOfHoleAtAnalyzer
--   내  용                : Analyzer에서 hole position별 Bottle 정보를 관리한다
--                          24개 hole 존재. hole갯수만큼 recode를 사전에 만들고 프로그램에서는 update만 수행
--
--                          -  가로 2자리(01~12) + 세로 2자리(01 ~ 02) +
--   성  격               : Process
--   보존기간              : 무관
--   Record 발생건수(1일)   : -
--   Total Record 수      : 12개
--   Record size          : 20
--   Total size           : 180 = 5 * 36
--   관리화면 유/무           : 유
--   P.K                  : EqpSeqNo, Position
--   관련 Table            :
--   이 력
--          1. 2024-07-07 : 최초 생성
--          2. 2024-07-14 : field 추가 (AllocationPriority, EventTime), bottle 투입하는 방법처리하기 위함
--             1) Position 기준으로 sorting 하는 방법
--             2) EventTime 기준으로 sorting 하는 방법 (순서적으로 순환하면서 hole 사용하는 방안)
--             3) AllocationPriority 기준으로 sorting 하는 방법. (hole 우선순위 정해서 사용하는 방안)
--
-- ========================================================================================
DROP TABLE tBottleInfoOfHoleAtAnalyzer;

CREATE TABLE tBottleInfoOfHoleAtAnalyzer (
   EqpSeqNo                 CHAR(1) NOT NULL,       -- 호기 (1부터 시작)
   Position                 CHAR(4) NOT NULL,       -- Analyzer에서 위치정보
   UsageFlag                CHAR(1) default 'O',    -- 'O':사용가능, 'X':사용불가
   AllocationPriority       TINYINT default 1,      -- 1 부터 시작
   EventTime                DATETIME,               -- Event Time
   BottleID                 CHAR(15)                -- Bottle ID
) ON [Process];

ALTER TABLE tBottleInfoOfHoleAtAnalyzer
       ADD  CONSTRAINT tBottleInfoOfHoleAtAnalyzer_PK PRIMARY KEY (EqpSeqNo, Position) ON [ProcessIdx];

-- 1열
INSERT INTO tBottleInfoOfHoleAtAnalyzer VALUES ('1', '0101', 'O', null);
INSERT INTO tBottleInfoOfHoleAtAnalyzer VALUES ('1', '0102', 'O', null);
INSERT INTO tBottleInfoOfHoleAtAnalyzer VALUES ('1', '0201', 'O', null);
INSERT INTO tBottleInfoOfHoleAtAnalyzer VALUES ('1', '0202', 'O', null);
INSERT INTO tBottleInfoOfHoleAtAnalyzer VALUES ('1', '0301', 'O', null);
INSERT INTO tBottleInfoOfHoleAtAnalyzer VALUES ('1', '0302', 'O', null);
INSERT INTO tBottleInfoOfHoleAtAnalyzer VALUES ('1', '0401', 'O', null);
INSERT INTO tBottleInfoOfHoleAtAnalyzer VALUES ('1', '0402', 'O', null);
INSERT INTO tBottleInfoOfHoleAtAnalyzer VALUES ('1', '0501', 'O', null);
INSERT INTO tBottleInfoOfHoleAtAnalyzer VALUES ('1', '0502', 'O', null);
INSERT INTO tBottleInfoOfHoleAtAnalyzer VALUES ('1', '0601', 'O', null);
INSERT INTO tBottleInfoOfHoleAtAnalyzer VALUES ('1', '0602', 'O', null);
INSERT INTO tBottleInfoOfHoleAtAnalyzer VALUES ('1', '0701', 'O', null);
INSERT INTO tBottleInfoOfHoleAtAnalyzer VALUES ('1', '0702', 'O', null);
INSERT INTO tBottleInfoOfHoleAtAnalyzer VALUES ('1', '0801', 'O', null);
INSERT INTO tBottleInfoOfHoleAtAnalyzer VALUES ('1', '0802', 'O', null);
INSERT INTO tBottleInfoOfHoleAtAnalyzer VALUES ('1', '0901', 'O', null);
INSERT INTO tBottleInfoOfHoleAtAnalyzer VALUES ('1', '0902', 'O', null);
INSERT INTO tBottleInfoOfHoleAtAnalyzer VALUES ('1', '1001', 'O', null);
INSERT INTO tBottleInfoOfHoleAtAnalyzer VALUES ('1', '1002', 'O', null);
INSERT INTO tBottleInfoOfHoleAtAnalyzer VALUES ('1', '1101', 'O', null);
INSERT INTO tBottleInfoOfHoleAtAnalyzer VALUES ('1', '1102', 'O', null);
INSERT INTO tBottleInfoOfHoleAtAnalyzer VALUES ('1', '1201', 'O', null);
INSERT INTO tBottleInfoOfHoleAtAnalyzer VALUES ('1', '1202', 'O', null);

-- ========================================================================================
--   Table No             : 9
--   Table 명             : tBottleInfoOfHoleAtMOMA
--   내  용                : MOMA에서 hole position별 Bottle 정보를 관리한다
--                          24개 hole 존재. hole갯수만큼 recode를 recode를 사전에 만들고 프로그램에서는 update만 수행
--
--                          MOMA : 24개 --> 장비에서 받는것 12, 장비에 적재하는것 12개 ==> 왜? 이렇게 운영하는지. 12개 안되나 ?
--                              - 가로 2자리(01~02), 세로 2자리(1 ~ 12)--
--   성  격               : Process
--   보존기간              : 무관
--   Record 발생건수(1일)   : -
--   Total Record 수      : 24개
--   Record size          : 20
--   Total size           : 180 = 5 * 36
--   관리화면 유/무           : 유
--   P.K                  : Position
--   관련 Table            :
--   이 력
--          1. 2024-07-06 : 최초 생성
--          2. 2024-07-14 : field 추가 (AllocationPriority, EventTime), bottle 투입하는 방법처리하기 위함
--             1) Position 기준으로 sorting 하는 방법
--             2) EventTime 기준으로 sorting 하는 방법 (순서적으로 순환하면서 hole 사용하는 방안)
--             3) AllocationPriority 기준으로 sorting 하는 방법. (hole 우선순위 정해서 사용하는 방안)
--
-- ========================================================================================
DROP TABLE tBottleInfoOfHoleAtMOMA;

CREATE TABLE tBottleInfoOfHoleAtMOMA (
   Position                 CHAR(4) NOT NULL,       -- MOMA에서 위치정보
   UsageFlag                CHAR(1) default 'O',    -- 'O':사용가능, 'X':사용불가
   AllocationPriority       TINYINT default 1,      -- 1 부터 시작
   EventTime                DATETIME,               -- Event Time
   BottleID                 CHAR(15)                -- Bottle ID
) ON [Process];

ALTER TABLE tBottleInfoOfHoleAtMOMA
       ADD  CONSTRAINT tBottleInfoOfHoleAtMOMA_PK PRIMARY KEY (Position) ON [ProcessIdx];

-- 1열
INSERT INTO tBottleInfoOfHoleAtMOMA VALUES ('0101', 'O', null);
INSERT INTO tBottleInfoOfHoleAtMOMA VALUES ('0201', 'O', null);
INSERT INTO tBottleInfoOfHoleAtMOMA VALUES ('0301', 'O', null);
INSERT INTO tBottleInfoOfHoleAtMOMA VALUES ('0401', 'O', null);
INSERT INTO tBottleInfoOfHoleAtMOMA VALUES ('0501', 'O', null);
INSERT INTO tBottleInfoOfHoleAtMOMA VALUES ('0601', 'O', null);
INSERT INTO tBottleInfoOfHoleAtMOMA VALUES ('0701', 'O', null);
INSERT INTO tBottleInfoOfHoleAtMOMA VALUES ('0801', 'O', null);
INSERT INTO tBottleInfoOfHoleAtMOMA VALUES ('0901', 'O', null);
INSERT INTO tBottleInfoOfHoleAtMOMA VALUES ('1001', 'O', null);
INSERT INTO tBottleInfoOfHoleAtMOMA VALUES ('1101', 'O', null);
INSERT INTO tBottleInfoOfHoleAtMOMA VALUES ('1201', 'O', null);

-- 2열
INSERT INTO tBottleInfoOfHoleAtMOMA VALUES ('0102', 'O', null);
INSERT INTO tBottleInfoOfHoleAtMOMA VALUES ('0202', 'O', null);
INSERT INTO tBottleInfoOfHoleAtMOMA VALUES ('0302', 'O', null);
INSERT INTO tBottleInfoOfHoleAtMOMA VALUES ('0402', 'O', null);
INSERT INTO tBottleInfoOfHoleAtMOMA VALUES ('0502', 'O', null);
INSERT INTO tBottleInfoOfHoleAtMOMA VALUES ('0602', 'O', null);
INSERT INTO tBottleInfoOfHoleAtMOMA VALUES ('0702', 'O', null);
INSERT INTO tBottleInfoOfHoleAtMOMA VALUES ('0802', 'O', null);
INSERT INTO tBottleInfoOfHoleAtMOMA VALUES ('0902', 'O', null);
INSERT INTO tBottleInfoOfHoleAtMOMA VALUES ('1002', 'O', null);
INSERT INTO tBottleInfoOfHoleAtMOMA VALUES ('1102', 'O', null);
INSERT INTO tBottleInfoOfHoleAtMOMA VALUES ('1202', 'O', null);

-- ========================================================================================
--   Table No             : 10
--   Table 명              : tProcScriptID4CoOperRobot
--   내  용                : tMstScriptID4CoOperRobot중 특정 동작을 별도 sub job으로 정의할때 사용
--   성  격                : Process
--   보존기간                : 영구
--   Record 발생건수(1일)    :
--   Total Record 수      : 5
--   Record size          : 31
--   Total size           : 155 = 5 * 31
--   관리화면 유/무           : 유
--   P.K                  : JobID, SequenceNum
--   관련 Table            :
--   이 력
--          1.2024-07-10 : 최초 생성
--
-- ========================================================================================
DROP TABLE tProcScriptID4CoOperRobot;
CREATE TABLE tProcScriptID4CoOperRobot; (
   JobID                    TINYINT  NOT NULL,      -- sub job ID
   SequenceNum              TINYINT  NOT NULL,      -- 분석실에서 사용하는 robot script 일련번호
   JobDescription           NVARCHAR(256)           -- Script 내용
}  ON [Process];

ALTER TABLE tMstScriptID4CoOperRobot
      ADD CONSTRAINT tMstScriptID4CoOperRobot_PK PRIMARY KEY (JobID, SequenceNum) ON [ProcessIdx];

INSERT INTO tProcScriptID4CoOperRobot VALUES (1, 1, 'Bottle 입출력기 관련 Sub Job');                    --

-- ========================================================================================
--   Table No             : 11
--   Table 명              : tProcSqlError
--   내  용                : stored procedure 실행중 발생한 error 저장
--   성  격                : Process
--   보존기간                : 1년
--   Record 발생건수(1일)    :
--   Total Record 수      : ?
--   Record size          : 31
--   Total size           : 155 = 5 * 31
--   관리화면 유/무           : 유
--   P.K                  : JobID, SequenceNum
--   관련 Table            :
--   이 력
--          1.2024-07-14 : 최초 생성
--
-- ========================================================================================
DROP TABLE tProcSqlError;
CREATE TABLE tProcSqlError (
   ErrorID                  INT AUTO_INCREMENT PRIMARY KEY,
   ProcedureName            VARCHAR(100),           -- stored procedure name
   ErrorCode                INT,                    -- sqlerror code
   ErrorMessage             VARCHAR(255),           -- error message
   ErrorTime                TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

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
   BottleID                 CHAR(15) NOT NULL,      -- Bottle ID
   EqpGroupID               CHAR(1) NOT NULL,       -- 설비군 ID
   OperID                   CHAR(1) NOT NULL,       -- 작업 ID
   StartTime                DATETIME NOT NULL,      -- 착공시간
   EndTime                  DATETIME,               -- 완공시간
   DispatchingPriority      TINYINT,                -- 반송우선순위 (1:가장 낮음, 9:Hot Run)
   Position                 CHAR(4)                 -- Bottle 반출입기, Stocker에서 위치정보
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
   EqpGroupID               CHAR(1) NOT NULL,       -- 설비군ID
   EqpSeqNo                 CHAR(1) NOT NULL,       -- 호기 (1부터 시작)
   EqpStatus                NVARCHAR(10),           -- 장비상태(Run, Idle, Trouble, Maintenance)
   StartTime                DATETIME,               -- 시작시간
   EndTime                  DATETIME                -- 종료시간
) ON [History];

ALTER TABLE tHisChgEqpStatus
      ADD  CONSTRAINT tHisChgEqpStatus_PK PRIMARY KEY (EqpGroupID, EqpSeqNo, EqpStatus,StartTime) ON [HistoryIdx];
	  
-- GPT prompt
-- tProcBottle에서 tBottleInfoOfHoleAtInOutBottle 의 Position 정보를 가져올수 있는  join table 만들어줘.
-- tProcBottle와 tBottleInfoOfHoleAtInOutBottle를 조인하는 뷰 생성
CREATE VIEW vBottleInfoWithPosition AS
SELECT
    pb.BottleID,
    pb.CurrEqpGroupID,
    pb.CurrEqpSeqNo,
    pb.CurrOperID,
    pb.NextEqpGroupID,
    pb.NextOperID,
    pb.ProjectNum,
    pb.PackID,
    pb.AnalyzerCompletedTm,
    pb.JudgeLimitTm,
    pb.JudgeOfResearcher,
    pb.ExperimentRequestID,
    pb.CurrLiquid,
    pb.RequestDate,
    pb.RequestTotCnt,
    pb.RequestRealCnt,
    pb.RequestSeqNo,
    pb.MemberOfBottlePack,
    pb.StartTime,
    pb.EndTime,
    pb.DispatchingPriority,
    pb.EventTime,
    pb.PrevLiquid,
    bih.ZoneName,
    bih.Position,
    bih.UsageFlag,
    bih.AllocationPriority,
    bih.EventTime AS BottleInfoEventTime
FROM
    tProcBottle pb
LEFT JOIN
    tBottleInfoOfHoleAtInOutBottle bih ON pb.BottleID = bih.BottleID;
	  