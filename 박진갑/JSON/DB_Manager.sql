1. 입고요청
   1) Token : LoadRequest
   2) 관련 controller : Bottle 반출입기, 분석기, Stocker, 폐기설비
                      UI에서 수동변경
   3) Body
      { 
         "EqpGroupID" : "1",
         "EqpSeqNo" : "1"
      } Or
      { 
         "EqpGroupID" : "1",
         "EqpSeqNo" : "1",
         "ProcessStatus" : "LoadReq"
      }      
   4) Function : tMstEqp table의 ProcessStatus(진행상태) 변경
   5) Return
      { 
         "status_code" : 200,
         "sender_controller" : "DB_Manager",    // 반출입기, Dispatcher, 분석기
         "error_msg" : "None"
      }      

2. 입고완료
   1) Token : LoadComp
   2) 관련 controller : Bottle 반출입기, 분석기, Stocker, 폐기설비
                      UI에서 수동변경
   3) Body
      { 
         "EqpGroupID" : "1",
         "EqpSeqNo" : "1",
         "BottleID" : "Bot20240602"
      } Or 
      { 
         "EqpGroupID" : "1",
         "EqpSeqNo" : "1",
         "BottleID" : "Bot20240602",
         "ProcessStatus" : "LoadComp"
      }      
   4) Function : tMstEqp table의 ProcessStatus(진행상태) 변경
   5) Return
      { 
         "status_code" : 200,
         "sender_controller" : "DB_Process",
         "error_msg" : "None"
      }  

3. 출하요청
   1) Token : UnloadRequest
   2) 관련 controller : Bottle 반출입기, 분석기, Stocker, 폐기설비
                      UI에서 수동변경
   3) Body
      { 
         "EqpGroupID" : "1",
         "EqpSeqNo" : "1",
         "BottleID" : "Bot20240602"
      } Or 
      { 
         "EqpGroupID" : "1",
         "EqpSeqNo" : "1",
         "BottleID" : "Bot20240602",
         "ProcessStatus" : "UnloadReq"
      }      
   4) Function : tMstEqp table의 ProcessStatus(진행상태) 변경
   5) Return
      { 
         "status_code" : 200,
         "sender_controller" : "DB_Process",
         "error_msg" : "None"
      }      

4. 출하완료
   1) Token : UnloadComp
   2) 관련 controller : Bottle 반출입기, 분석기, Stocker, 폐기설비
                      UI에서 수동변경
   3) Body
      { 
         "EqpGroupID" : "1",
         "EqpSeqNo" : "1",
         "BottleID" : "Bot20240602"
      } Or 
      { 
         "EqpGroupID" : "1",
         "EqpSeqNo" : "1",
         "BottleID" : "Bot20240602",
         "ProcessStatus" : "UnloadComp"
      }      
   4) Function : tMstEqp table의 ProcessStatus(진행상태) 변경
   5) Return
      { 
         "status_code" : 200,
         "sender_controller" : "DB_Process",
         "error_msg" : "None"
      } 


5. 장비반송 사전예약, 다른 Process에서 해당장비 반송을 못하도록 하기 위함
   Dispatcher에서 To Position 정해지면 To Position을 Reserve한다.
   1) Token : DispatchReserve
   2) 관련 controller : Dispatcher
                      UI에서 수동변경
   3) Body
      { 
         "EqpGroupID" : "1",
         "EqpSeqNo" : "1"
      } Or 
      { 
         "EqpGroupID" : "1",
         "EqpSeqNo" : "1",
         "ProcessStatus" : "Reserve"       -- Next Eqp 상태를 Reserver 변경함
      }      
   4) Function : tMstEqp table의 ProcessStatus(진행상태)를 변경
   5) Return
      { 
         "status_code" : 200,
         "sender_controller" : "DB_Process",
         "error_msg" : "None"
      } 

6. Process상태변경
   LoadRequest, LoadComp, UnloadRequest, UnloadComp 통합하는 것도 가능
   1) Token : ChangeProcessStatus
   2) 관련 controller : Bottle 반출입기, 분석기, Stocker, 폐기설비
                      UI에서 수동변경     
   3-2) Body 
      { 
         "EqpGroupID" : "2",
         "EqpSeqNo" : "1",
         "BottleID" : "Bot20240602",
         "EqpStatus" : "Run" 
      }    
   4) Function : tMstEqp table의 EqpStatus(장비상태) 변경
   5) Return
      { 
         "status_code" : 200,
         "sender_controller" : "DB_Process",
         "error_msg" : "None"
      } 
      
7. 장비상태변경
   1) Token : ChangeEqpStatus
   2) 관련 controller : Bottle 반출입기, 분석기, Stocker, 폐기설비
                      UI에서 수동변경     
   3-2) Body 
      { 
         "EqpGroupID" : "2",
         "EqpSeqNo" : "1",
         "EqpStatus" : "Run" 
      }    
   4) Function : tMstEqp table의 EqpStatus(장비상태) 변경
   5) Return
      { 
         "status_code" : 200,
         "sender_controller" : "DB_Process",
         "error_msg" : "None"
      }      
      
8. 장비상태요청
   1) Token : ReqEqpsStatus
   2) 관련 controller : Dispatch,
                      UI
   3) Body
      { 
         None
      }      
   4) Function : tMstEqp table의 모든 EqpStatus(장비상태) 요청
   5) Return
      { 
         "status_code" : 200,
         "sender_controller" : "DB_Process",
         "total_cnt_of_eqp" : 5,
         "eqp_status" : [
            { "No_1" : {
                 "EqpGroupID" : "1", "EqpSeqNo" : "1", "ProcessStatus":"UnloadReq", "EqpStatus" : "Idle"}
            },
            { "No_2" : {
                 "EqpGroupID" : "2", "EqpSeqNo" : "1", "ProcessStatus":"Idle","EqpStatus" : "Run"}
            },
            ...
            { "No_5" : {
                 "EqpGroupID" : "5", "EqpSeqNo" : "1", "ProcessStatus":"LoadComp","EqpStatus" : "Idle"}
            }
         ],
         "error_msg" : "None"
      } 
      
9. 분석기장비상태요청
   1) Token : ReqAnalysisEqpStatus
   2) 관련 controller : Dispatch,
                      UI
   3) Body
      { 
         "EqpGroupID" : "2",
         "EqpSeqNo" : "1",
      }      
   4) Function : tMstEqp table의 EqpStatus(장비상태) 요청
   5) Return
      { 
         "status_code" : 200,
         "sender_controller" : "DB_Process",
         "eqp_status" : "Run",
         "process_status" : "UnloadReq",
         "error_msg" : "None"
      } 
      
10. Bottle정보변겅

11. Bottle 정보요청
