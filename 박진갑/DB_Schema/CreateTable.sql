-- ============================================================================ 
-- Table Space 명   : MASTER
-- 내 용            : Master관련 table을 관리하는 table space
--
-- 관련 MASTER Table
--
--           No.   Table 명                   Size
--          ----  -----------------         --------
--            1     tMstEqpGroup               1 K
--            2     tMstEqp                    1 K
--            3     tMstOperation              1 K
--            4     tMstBottle                 1 K

-- ============================================================================ 
-- Table Space 명   : Master
-- 내 용            : 공정관련 table을 관리하는 table space
--
-- 관련 Master Table
--           No.    Table 명             Size   
--          ----  --------------------  ------------
--            1     tMstEqpGroup

-- ========================================================================================
--   Table No             : 1
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
      
INSERT INTO tMstEqpGroup VALUES ('1', N'반출입기');
INSERT INTO tMstEqpGroup VALUES ('2', N'분석기');
INSERT INTO tMstEqpGroup VALUES ('3', N'Stocker');      -- Stocker #1호기
INSERT INTO tMstEqpGroup VALUES ('4', N'폐기설비');
INSERT INTO tMstEqpGroup VALUES ('5', N'이동형협업로봇');



-- ========================================================================================
--   Table No             : 2
--   Table 명             : tMstEqp 
--   내  용               : LIMS 설비군을 관리하는 Table
--                         현재는 설비군별 장비가 1대지만, 향후 장비추가를 대비해서 EqpSeqNo 추가
--                         Bottle 반출입기, 스토커 Full인 경우 상태를 'Trouble' 변경
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
--
-- ========================================================================================
DROP TABLE tMstEqp;

CREATE TABLE tMstEqp (
   EqpGroupID             CHAR(1) NOT NULL,         -- 설비군ID
   EqpSeqNo               CHAR(1) NOT NULL,         -- 호기 (1부터 시작)
   EqpName                NVARCHAR(30),             -- 설비명 
   EqpStatus              NVARCHAR(10),             -- 장비상태 (PowerOn, PowerOff, Run, Idle, Trouble, Maintenance)
   ProcessStatus          NVARCHAR(12),             -- 진행 상태(LoadReq, LoadComp, UnlLoadReq, UnlLoadComp, Idle, Pause, Reserve)
   EqpTimeWriteLog        INT default 0             -- 장비 내부 LOG 저장 시간
) ON [Master];

ALTER TABLE tMstEqp 
      ADD CONSTRAINT tMstEqp_PK PRIMARY KEY (EqpGroupID, EqpSeqNo) ON [MasterIdx];
ALTER TABLE tMstEqp 
      ADD CONSTRAINT tMstEqp_FK FOREIGN KEY (EqpGroupID) REFERENCES tMstEqpGroup(EqpGroupID) ON [MasterIdx];
ALTER TABLE tMstEqp 
      ADD CONSTRAINT tMstEqp_CHK CHECK (EqpStatus in ("PowerOn", "PowerOff", "Run", "Idle", "Trouble", "Maintenance")) ON [MasterIdx];
      
INSERT INTO tMstEqp VALUES ('1', '1', N'반출입기', "Idle");
INSERT INTO tMstEqp VALUES ('2', '1', N'분석기', "Idle");
INSERT INTO tMstEqp VALUES ('3', '1', N'Stocker', "Idle");      -- Stocker #1호기
INSERT INTO tMstEqp VALUES ('4', '1', N'폐기설비', "Idle");
INSERT INTO tMstEqp VALUES ('5', '1', N'이동형협업로봇', "Idle");


-- ========================================================================================
--   Table No             : 3
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

INSERT INTO tMstOperation VALUES ('1', '1', N'Bottle 반출요청');
INSERT INTO tMstOperation VALUES ('1', '2', N'Bottle 반출');
INSERT INTO tMstOperation VALUES ('1', '3', N'Bottle Loader 투입요청');   -- UnloadRequest event
INSERT INTO tMstOperation VALUES ('1', '4', N'Bottle 출하대기');
INSERT INTO tMstOperation VALUES ('1', '5', N'Bottle 보관');        -- 세정후 재사용을 위하여 Bottle 반출입기에 보관

INSERT INTO tMstOperation VALUES ('2', '1', N'분석 작업중');
INSERT INTO tMstOperation VALUES ('3', '1', N'Stocker 입고');       -- 
INSERT INTO tMstOperation VALUES ('4', '1', N'폐기설비 작업중');
INSERT INTO tMstOperation VALUES ('5', '1', N'이동형협업로봇 이동중');


-- ========================================================================================
--   Table No             : 4
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
   BottleID               CHAR(1) NOT NULL,         -- 설비군ID
   Creation               DATETIME                  -- 생성일
) ON [Master];

ALTER TABLE tMstBottle
      ADD CONSTRAINT tMstBottle_PK PRIMARY KEY (BottleID) ON [MasterIdx];

-- ========================================================================================
--   Table No             : 5
--   Table 명             : tMstRoute
--   내  용                : LIMS Route을 관리하는 Table
--                         분석실에서 현재 1개 Route로 처리가능함
--                         분석기에서 판정후 Stocker Or 폐기/모사 이동할수 있음
--                         주의) Dispatcher는 분석의뢰자가 Bottle 반출입기 투입후 Stocker에서 투입할 Bottle 없고 
--                              분석기 상태가 Idle일때는 Stocker대기 없이 Bottle 반출입기에서 분석기로 바로 이동
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
DROP TABLE tMstRoute;

CREATE TABLE tMstRoute (
   RouteID                CHAR(1) NOT NULL,         -- Route ID
   -- 현공정에 대한 정의  
   CurrEqpGroupID         CHAR(1) NOT NULL,         -- 현재 설비군 ID 
   CurrOperID             CHAR(1) NOT NULL,         -- 현재 작업 ID
   -- 다음공정에 대한 정의  
   NextEqpGroupID         CHAR(1) NOT NULL,         -- 차기 설비군 ID 
   NextOperID             CHAR(1) NOT NULL          -- 차기 작업 ID
) ON [Master];

ALTER TABLE tMstRoute
       ADD CONSTRAINT tMstRoute_PK PRIMARY KEY (RouteID, CurrEqpGroupID, CurrOperID, NextEqpGroupID) ON [MasterIdx];

INSERT INTO tMstRoute VALUES ('1', '0', '0', '1', '1');
INSERT INTO tMstRoute VALUES ('1', '1', '1', '1', '2');
INSERT INTO tMstRoute VALUES ('1', '1', '2', '1', '3');
INSERT INTO tMstRoute VALUES ('1', '1', '3', '3', '1');     -- UnloadRequest event
INSERT INTO tMstRoute VALUES ('1', '1', '3', '2', '1');     -- UnloadRequest event
INSERT INTO tMstRoute VALUES ('1', '3', '1', '2', '1');
INSERT INTO tMstRoute VALUES ('1', '2', '1', '3', '1');     -- 분석후 Stocker 이동
INSERT INTO tMstRoute VALUES ('1', '2', '1', '5', '1');     -- 분석후 폐기/모사 이동


-- ========================================================================================
--   Table No             : 1
--   Table 명             : tProcBottle
--   내  용                : LIMS Bottle을 관리하는 Table
--                         tMstBottle에서는 Bottle정보가 변경되지 않는 것을 관리하고
--                         tProcBottle에서는 공정진행하면서 정보가 변경되는 것을 별도 Table 관리
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
--
-- ========================================================================================
DROP TABLE tProcBottle;

CREATE TABLE tProcBottle (
   BottleID               CHAR(1) NOT NULL,         -- 설비군ID
   ExperimentRequestName  NVARCHAR(10),             -- 실험의뢰자
   CurrLiquid             NVARCHAR(10),             -- 용액종료 (산, 염기, 유기)
   RequestDate            DATETIME,                 -- 요청일시
   DispatchingPriority    TINYINT,                  -- 반송우선순위 (1:가장 낮음, 9:Hot Run)
   Position               CHAR(4),                  -- Bottle 반출입기, Stocker에서 위치정보
   PrevLiquid             NVARCHAR(10),             -- 이전 작업에서 용액종료 (산, 염기, 유기)
) ON [Process];

ALTER TABLE tProcBottle
       ADD  CONSTRAINT tProcBottle_PK PRIMARY KEY (BottleID) ON [ProcessIdx];
ALTER TABLE tProcBottle 
      ADD CONSTRAINT tProcBottle_FK FOREIGN KEY (BottleID) REFERENCES tMstEqpGroup(BottleID) ON [ProcessIdx];

-- ========================================================================================
--   Table No             : 2
--   Table 명             : tProcBotCurrOper
--   내  용                : LIMS Bottle에서 작업이력을 관리하는 Table
--                         tMstBottle에서는 Bottle정보가 변경되지 않는 것을 관리하고
--                         tProcBottle에서는 공정진행하면서 정보가 변경되는 것을 별도 Table 관리
--
--   성  격               : Process
--   보존기간              : 영구
--   Record 발생건수(1일)   :
--   Total Record 수      : 5
--   Record size          : 25
--   Total size           : 180 = 5 * 36
--   관리화면 유/무           : 유
--   P.K                  : BottleID
--   관련 Table            : 
--   이 력
--          1. 2024-06-01 : 최초 생성
--
-- ========================================================================================
DROP TABLE tProcBotCurrOper;

CREATE TABLE tProcBotCurrOper (
   BottleID               CHAR(1) NOT NULL,         -- 설비군ID
   EqpGroupID             CHAR(1) NOT NULL,         -- 설비군 ID 
   --OperGroupID          CHAR(1) NOT NULL,         -- Operation Group 
   OperID                 CHAR(1) NOT NULL,         -- 작업 ID  
   StartTime              DATETIME NOT NULL,        -- 착공시간
   EndTime                DATETIME,                 -- 완공시간
   DispatchingPriority    TINYINT,                  -- 반송우선순위 (1:가장 낮음, 9:Hot Run)
   Position               CHAR(4)                   -- Bottle 반출입기, Stocker에서 위치정보
) ON [Process];

ALTER TABLE tProcBotCurrOper
      ADD  CONSTRAINT ttProcBotCurrOper_PK PRIMARY KEY (BottleID, EqpGroupID, OperID, StartTime) ON [ProcessIdx];

-- ========================================================================================
--   Table No             : 3
--   Table 명             : tChgEqpStatus
--   내  용                : 장비사용시간 관리하는 Table
--                          Bottle 반출입기, Stocker는 설비내 Bottle 항상 있는 상태이므로 의미 없음
--                          분석기, 폐기/모사에 대한 장비상태 관리
--                          날짜가 변경될때 관리할 방법 고민필요
--
--   성  격               : Process
--   보존기간              : 3년
--   Record 발생건수(1일)   : 
--   Total Record 수      : 300개
--   Record size          : 28
--   Total size           : 180 = 5 * 36
--   관리화면 유/무           : 유
--   P.K                  : BottleID
--   관련 Table            : 
--   이 력
--          1. 2024-06-01 : 최초 생성
--
-- ========================================================================================
DROP TABLE tChgEqpStatus;

CREATE TABLE tChgEqpStatus (
   EqpGroupID             CHAR(1) NOT NULL,         -- 설비군ID
   EqpSeqNo               CHAR(1) NOT NULL,         -- 호기 (1부터 시작)
   EqpStatus              NVARCHAR(10),             -- 장비상태(Run, Idle, Trouble, Maintenance)
   StartTime              DATETIME,                 -- 시작시간
   EndTime                DATETIME                  -- 종료시간
) ON [Process];

ALTER TABLE tChgEqpStatus
       ADD  CONSTRAINT tChgEqpStatus_PK PRIMARY KEY (EqpGroupID, EqpSeqNo) ON [ProcessIdx];
ALTER TABLE tChgEqpStatus 
      ADD CONSTRAINT tChgEqpStatus_FK FOREIGN KEY (EqpGroupID, EqpSeqNo) REFERENCES tMstEqpGroup(EqpGroupID, EqpSeqNo) ON [ProcessIdx];

-- ========================================================================================
--   Table No             : 4
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
--   P.K                  : BottleID
--   관련 Table            : 
--   이 력
--          1. 2024-06-01 : 최초 생성
--
-- ========================================================================================
DROP TABLE tDailyEqpStatus;

CREATE TABLE tDailyEqpStatus (
   EqpGroupID             CHAR(1) NOT NULL,         -- 설비군ID
   EqpSeqNo               CHAR(1) NOT NULL,         -- 호기 (1부터 시작)
   EqpStatus              NVARCHAR(10),             -- 장비상태(Run, Idle, Trouble, Maintenance)
   AccumulateTime         DATETIME                  -- 누적시간 (24시간 넘을수 없다)
) ON [Process];

ALTER TABLE tDailyEqpStatus
       ADD  CONSTRAINT tDailyEqpStatus_PK PRIMARY KEY (EqpGroupID, EqpSeqNo) ON [ProcessIdx];
ALTER TABLE tDailyEqpStatus 
      ADD CONSTRAINT tDailyEqpStatus_FK FOREIGN KEY (EqpGroupID, EqpSeqNo) REFERENCES tMstEqpGroup(EqpGroupID, EqpSeqNo) ON [ProcessIdx];
ALTER TABLE tDailyEqpStatus
      ADD CONSTRAINT tDailyEqpStatus_CHK_status CHECK (EqpStatus IN ('Run', 'Idle', 'Trouble', 'Maintenance')) ON [ProcessIdx];
ALTER TABLE tDailyEqpStatus
      ADD CONSTRAINT tDailyEqpStatus_CHK_AccumulateTime CHECK (TIMEDIFF(AccumulateTime, '0000-01-01 00:00:00') <= '24:00:00') ON [ProcessIdx];
   
-- ========================================================================================
--   Table No             : 1
--   Table 명             : tProcBotHistOper
--   내  용                : LIMS Bottle 세정후에 tProcBotCurrOper에서 tProcBotHistOper 이동
--
--   성  격               : Process
--   보존기간              : 영구
--   Record 발생건수(1일)   :
--   Total Record 수      : 5
--   Record size          : 25
--   Total size           : 180 = 5 * 36
--   관리화면 유/무           : 유
--   P.K                  : BottleID
--   관련 Table            : 
--   이 력
--          1. 2024-06-01 : 최초 생성
--
-- ========================================================================================
DROP TABLE tProcBotHistOper;

CREATE TABLE tProcBotHistOper (
   BottleID               CHAR(1) NOT NULL,         -- 설비군ID
   EqpGroupID             CHAR(1) NOT NULL,         -- 설비군 ID 
   --OperGroupID          CHAR(1) NOT NULL,         -- Operation Group 
   OperID                 CHAR(1) NOT NULL,         -- 작업 ID  
   StartTime              DATETIME NOT NULL,        -- 착공시간
   EndTime                DATETIME,                 -- 완공시간
   DispatchingPriority    TINYINT,                  -- 반송우선순위 (1:가장 낮음, 9:Hot Run)
   Position               CHAR(4)                   -- Bottle 반출입기, Stocker에서 위치정보
) ON [History];

ALTER TABLE tProcBotHistOper
      ADD  CONSTRAINT tProcBotHistOper_PK PRIMARY KEY (BottleID, EqpGroupID, OperID, StartTime) ON [HistoryIdx];
