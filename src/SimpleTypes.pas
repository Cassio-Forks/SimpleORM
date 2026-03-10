unit SimpleTypes;

interface

type
  TSQLType = (Firebird, MySQL, SQLite, Oracle);
  TRuleAction = (raBeforeInsert, raAfterInsert, raBeforeUpdate, raAfterUpdate, raBeforeDelete, raAfterDelete);
  TSkillRunAt = (srBeforeInsert, srAfterInsert, srBeforeUpdate, srAfterUpdate, srBeforeDelete, srAfterDelete);
  TSkillRunMode = (srmNormal, srmOnError);
  TAgentOperation = (aoAfterInsert, aoAfterUpdate, aoAfterDelete);
  TAgentCondition = reference to function(aEntity: TObject): Boolean;

  TSupabaseEventType = (setInsert, setUpdate, setDelete);

  TSupabaseRealtimeEvent = record
    Table: String;
    EventType: TSupabaseEventType;
    OldRecord: String;
    NewRecord: String;
  end;

  TSupabaseRealtimeCallback = reference to procedure(aEvent: TSupabaseRealtimeEvent);

  TSimpleErrorCallback = reference to procedure(aEntity: TObject; aException: Exception);

implementation

end.
