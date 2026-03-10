unit SimpleTypes;

interface

type
  TSQLType = (Firebird, MySQL, SQLite, Oracle);
  TRuleAction = (raBeforeInsert, raAfterInsert, raBeforeUpdate, raAfterUpdate, raBeforeDelete, raAfterDelete);
  TSkillRunAt = (srBeforeInsert, srAfterInsert, srBeforeUpdate, srAfterUpdate, srBeforeDelete, srAfterDelete);
  TAgentOperation = (aoAfterInsert, aoAfterUpdate, aoAfterDelete);
  TAgentCondition = reference to function(aEntity: TObject): Boolean;

implementation

end.
