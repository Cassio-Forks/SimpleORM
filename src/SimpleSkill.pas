unit SimpleSkill;

interface

uses
  SimpleInterface,
  SimpleAttributes,
  SimpleRTTIHelper,
  SimpleTypes,
  SimpleLogger,
  System.Net.HttpClient,
  System.JSON,
  System.DateUtils,
  System.SysUtils,
  System.Rtti,
  System.Generics.Collections;

type
  ESimpleGuardDelete = class(Exception);

  TSimpleSkillContext = class(TInterfacedObject, iSimpleSkillContext)
  private
    FQuery: iSimpleQuery;
    FAIClient: iSimpleAIClient;
    FLogger: iSimpleQueryLogger;
    FEntityName: String;
    FOperation: String;
  public
    constructor Create(aQuery: iSimpleQuery; aAIClient: iSimpleAIClient;
      aLogger: iSimpleQueryLogger; const aEntityName, aOperation: String);
    destructor Destroy; override;
    class function New(aQuery: iSimpleQuery; aAIClient: iSimpleAIClient;
      aLogger: iSimpleQueryLogger; const aEntityName, aOperation: String): iSimpleSkillContext;
    function Query: iSimpleQuery;
    function AIClient: iSimpleAIClient;
    function Logger: iSimpleQueryLogger;
    function EntityName: String;
    function Operation: String;
  end;

  TSimpleSkillRunner = class
  private
    FSkills: TList<iSimpleSkill>;
  public
    constructor Create;
    destructor Destroy; override;
    class function New: TSimpleSkillRunner;
    procedure Add(aSkill: iSimpleSkill);
    procedure RunBefore(aEntity: TObject; aContext: iSimpleSkillContext; aRunAt: TSkillRunAt);
    procedure RunAfter(aEntity: TObject; aContext: iSimpleSkillContext; aRunAt: TSkillRunAt);
    function Count: Integer;
  end;

  { Built-in: TSkillLog }
  TSkillLog = class(TInterfacedObject, iSimpleSkill)
  private
    FPrefix: String;
    FRunAt: TSkillRunAt;
  public
    constructor Create(const aPrefix: String = ''; aRunAt: TSkillRunAt = srAfterInsert);
    destructor Destroy; override;
    class function New(const aPrefix: String = ''; aRunAt: TSkillRunAt = srAfterInsert): iSimpleSkill;
    function Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
    function Name: String;
    function RunAt: TSkillRunAt;
  end;

  { Built-in: TSkillNotify }
  TSkillNotify = class(TInterfacedObject, iSimpleSkill)
  private
    FCallback: TProc<TObject>;
    FRunAt: TSkillRunAt;
  public
    constructor Create(aCallback: TProc<TObject>; aRunAt: TSkillRunAt = srAfterInsert);
    destructor Destroy; override;
    class function New(aCallback: TProc<TObject>; aRunAt: TSkillRunAt = srAfterInsert): iSimpleSkill;
    function Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
    function Name: String;
    function RunAt: TSkillRunAt;
  end;

  { Built-in: TSkillAudit }
  TSkillAudit = class(TInterfacedObject, iSimpleSkill)
  private
    FAuditTable: String;
    FRunAt: TSkillRunAt;
  public
    constructor Create(const aAuditTable: String = 'AUDIT_LOG'; aRunAt: TSkillRunAt = srAfterInsert);
    destructor Destroy; override;
    class function New(const aAuditTable: String = 'AUDIT_LOG'; aRunAt: TSkillRunAt = srAfterInsert): iSimpleSkill;
    function Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
    function Name: String;
    function RunAt: TSkillRunAt;
  end;

  { Built-in: TSkillTimestamp }
  TSkillTimestamp = class(TInterfacedObject, iSimpleSkill)
  private
    FFieldName: String;
    FRunAt: TSkillRunAt;
  public
    constructor Create(const aFieldName: String; aRunAt: TSkillRunAt = srBeforeInsert);
    destructor Destroy; override;
    class function New(const aFieldName: String; aRunAt: TSkillRunAt = srBeforeInsert): iSimpleSkill;
    function Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
    function Name: String;
    function RunAt: TSkillRunAt;
  end;

  { Built-in: TSkillHistory }
  TSkillHistory = class(TInterfacedObject, iSimpleSkill)
  private
    FHistoryTable: String;
    FRunAt: TSkillRunAt;
  public
    constructor Create(const aHistoryTable: String = 'ENTITY_HISTORY'; aRunAt: TSkillRunAt = srBeforeUpdate);
    destructor Destroy; override;
    class function New(const aHistoryTable: String = 'ENTITY_HISTORY'; aRunAt: TSkillRunAt = srBeforeUpdate): iSimpleSkill;
    function Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
    function Name: String;
    function RunAt: TSkillRunAt;
  end;

  { Built-in: TSkillValidate }
  TSkillValidate = class(TInterfacedObject, iSimpleSkill)
  private
    FRunAt: TSkillRunAt;
  public
    constructor Create(aRunAt: TSkillRunAt = srBeforeInsert);
    destructor Destroy; override;
    class function New(aRunAt: TSkillRunAt = srBeforeInsert): iSimpleSkill;
    function Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
    function Name: String;
    function RunAt: TSkillRunAt;
  end;

  { Built-in: TSkillWebhook }
  TSkillWebhook = class(TInterfacedObject, iSimpleSkill)
  private
    FURL: String;
    FRunAt: TSkillRunAt;
    FAuthHeader: String;
  public
    constructor Create(const aURL: String; aRunAt: TSkillRunAt = srAfterInsert;
      const aAuthHeader: String = '');
    destructor Destroy; override;
    class function New(const aURL: String; aRunAt: TSkillRunAt = srAfterInsert;
      const aAuthHeader: String = ''): iSimpleSkill;
    function Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
    function Name: String;
    function RunAt: TSkillRunAt;
  end;

  { Built-in: TSkillGuardDelete }
  TSkillGuardDelete = class(TInterfacedObject, iSimpleSkill)
  private
    FTable: String;
    FFKField: String;
  public
    constructor Create(const aTable, aFKField: String);
    destructor Destroy; override;
    class function New(const aTable, aFKField: String): iSimpleSkill;
    function Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
    function Name: String;
    function RunAt: TSkillRunAt;
  end;

  { Built-in: TSkillSequence }
  TSkillSequence = class(TInterfacedObject, iSimpleSkill)
  private
    FFieldName: String;
    FControlTable: String;
    FSerie: String;
  public
    constructor Create(const aFieldName, aControlTable, aSerie: String);
    destructor Destroy; override;
    class function New(const aFieldName, aControlTable, aSerie: String): iSimpleSkill;
    function Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
    function Name: String;
    function RunAt: TSkillRunAt;
  end;

implementation

uses
  SimpleValidator,
  SimpleSerializer;

{ TSimpleSkillContext }

constructor TSimpleSkillContext.Create(aQuery: iSimpleQuery; aAIClient: iSimpleAIClient;
  aLogger: iSimpleQueryLogger; const aEntityName, aOperation: String);
begin
  FQuery := aQuery;
  FAIClient := aAIClient;
  FLogger := aLogger;
  FEntityName := aEntityName;
  FOperation := aOperation;
end;

destructor TSimpleSkillContext.Destroy;
begin
  inherited;
end;

class function TSimpleSkillContext.New(aQuery: iSimpleQuery; aAIClient: iSimpleAIClient;
  aLogger: iSimpleQueryLogger; const aEntityName, aOperation: String): iSimpleSkillContext;
begin
  Result := Self.Create(aQuery, aAIClient, aLogger, aEntityName, aOperation);
end;

function TSimpleSkillContext.Query: iSimpleQuery;
begin
  Result := FQuery;
end;

function TSimpleSkillContext.AIClient: iSimpleAIClient;
begin
  Result := FAIClient;
end;

function TSimpleSkillContext.Logger: iSimpleQueryLogger;
begin
  Result := FLogger;
end;

function TSimpleSkillContext.EntityName: String;
begin
  Result := FEntityName;
end;

function TSimpleSkillContext.Operation: String;
begin
  Result := FOperation;
end;

{ TSimpleSkillRunner }

constructor TSimpleSkillRunner.Create;
begin
  FSkills := TList<iSimpleSkill>.Create;
end;

destructor TSimpleSkillRunner.Destroy;
begin
  FreeAndNil(FSkills);
  inherited;
end;

class function TSimpleSkillRunner.New: TSimpleSkillRunner;
begin
  Result := Self.Create;
end;

procedure TSimpleSkillRunner.Add(aSkill: iSimpleSkill);
begin
  FSkills.Add(aSkill);
end;

procedure TSimpleSkillRunner.RunBefore(aEntity: TObject; aContext: iSimpleSkillContext; aRunAt: TSkillRunAt);
var
  LSkill: iSimpleSkill;
begin
  for LSkill in FSkills do
  begin
    if LSkill.RunAt = aRunAt then
      LSkill.Execute(aEntity, aContext);
  end;
end;

procedure TSimpleSkillRunner.RunAfter(aEntity: TObject; aContext: iSimpleSkillContext; aRunAt: TSkillRunAt);
var
  LSkill: iSimpleSkill;
begin
  for LSkill in FSkills do
  begin
    if LSkill.RunAt = aRunAt then
      LSkill.Execute(aEntity, aContext);
  end;
end;

function TSimpleSkillRunner.Count: Integer;
begin
  Result := FSkills.Count;
end;

{ TSkillLog }

constructor TSkillLog.Create(const aPrefix: String; aRunAt: TSkillRunAt);
begin
  FPrefix := aPrefix;
  FRunAt := aRunAt;
end;

destructor TSkillLog.Destroy;
begin
  inherited;
end;

class function TSkillLog.New(const aPrefix: String; aRunAt: TSkillRunAt): iSimpleSkill;
begin
  Result := Self.Create(aPrefix, aRunAt);
end;

function TSkillLog.Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
var
  LMsg: String;
begin
  Result := Self;
  LMsg := '[Skill:Log]';
  if FPrefix <> '' then
    LMsg := LMsg + ' ' + FPrefix;
  LMsg := LMsg + ' ' + aContext.Operation + ' ' + aContext.EntityName;
  if aEntity <> nil then
    LMsg := LMsg + ' (' + aEntity.ClassName + ')';

  if Assigned(aContext.Logger) then
    aContext.Logger.Log(LMsg, nil, 0)
  else
  begin
    {$IFDEF MSWINDOWS}
    OutputDebugString(PChar(LMsg));
    {$ENDIF}
    {$IFDEF CONSOLE}
    Writeln(LMsg);
    {$ENDIF}
  end;
end;

function TSkillLog.Name: String;
begin
  Result := 'log';
end;

function TSkillLog.RunAt: TSkillRunAt;
begin
  Result := FRunAt;
end;

{ TSkillNotify }

constructor TSkillNotify.Create(aCallback: TProc<TObject>; aRunAt: TSkillRunAt);
begin
  FCallback := aCallback;
  FRunAt := aRunAt;
end;

destructor TSkillNotify.Destroy;
begin
  inherited;
end;

class function TSkillNotify.New(aCallback: TProc<TObject>; aRunAt: TSkillRunAt): iSimpleSkill;
begin
  Result := Self.Create(aCallback, aRunAt);
end;

function TSkillNotify.Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
begin
  Result := Self;
  if Assigned(FCallback) then
    FCallback(aEntity);
end;

function TSkillNotify.Name: String;
begin
  Result := 'notify';
end;

function TSkillNotify.RunAt: TSkillRunAt;
begin
  Result := FRunAt;
end;

{ TSkillAudit }

constructor TSkillAudit.Create(const aAuditTable: String; aRunAt: TSkillRunAt);
begin
  FAuditTable := aAuditTable;
  FRunAt := aRunAt;
end;

destructor TSkillAudit.Destroy;
begin
  inherited;
end;

class function TSkillAudit.New(const aAuditTable: String; aRunAt: TSkillRunAt): iSimpleSkill;
begin
  Result := Self.Create(aAuditTable, aRunAt);
end;

function TSkillAudit.Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
var
  LSQL: String;
begin
  Result := Self;
  if aContext.Query = nil then
    Exit;

  LSQL := 'INSERT INTO ' + FAuditTable +
    ' (ENTITY_NAME, OPERATION, CREATED_AT) VALUES (:pEntity, :pOperation, :pCreatedAt)';

  aContext.Query.SQL.Clear;
  aContext.Query.SQL.Add(LSQL);
  aContext.Query.Params.ParamByName('pEntity').Value := aContext.EntityName;
  aContext.Query.Params.ParamByName('pOperation').Value := aContext.Operation;
  aContext.Query.Params.ParamByName('pCreatedAt').Value := Now;
  aContext.Query.ExecSQL;
end;

function TSkillAudit.Name: String;
begin
  Result := 'audit';
end;

function TSkillAudit.RunAt: TSkillRunAt;
begin
  Result := FRunAt;
end;

{ TSkillTimestamp }

constructor TSkillTimestamp.Create(const aFieldName: String; aRunAt: TSkillRunAt);
begin
  FFieldName := aFieldName;
  FRunAt := aRunAt;
end;

destructor TSkillTimestamp.Destroy;
begin
  inherited;
end;

class function TSkillTimestamp.New(const aFieldName: String; aRunAt: TSkillRunAt): iSimpleSkill;
begin
  Result := Self.Create(aFieldName, aRunAt);
end;

function TSkillTimestamp.Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
begin
  Result := Self;
  if aEntity = nil then
    Exit;

  LContext := TRttiContext.Create;
  LType := LContext.GetType(aEntity.ClassType);
  LProp := LType.GetProperty(FFieldName);
  if LProp <> nil then
    LProp.SetValue(aEntity, TValue.From<TDateTime>(Now));
end;

function TSkillTimestamp.Name: String;
begin
  Result := 'timestamp';
end;

function TSkillTimestamp.RunAt: TSkillRunAt;
begin
  Result := FRunAt;
end;

{ TSkillGuardDelete }

constructor TSkillGuardDelete.Create(const aTable, aFKField: String);
begin
  FTable := aTable;
  FFKField := aFKField;
end;

destructor TSkillGuardDelete.Destroy;
begin
  inherited;
end;

class function TSkillGuardDelete.New(const aTable, aFKField: String): iSimpleSkill;
begin
  Result := Self.Create(aTable, aFKField);
end;

function TSkillGuardDelete.Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LPKValue: Variant;
  LCount: Integer;
begin
  Result := Self;
  if (aEntity = nil) or (aContext.Query = nil) then
    Exit;

  LContext := TRttiContext.Create;
  LType := LContext.GetType(aEntity.ClassType);

  LProp := LType.GetPKField;
  if LProp = nil then
    Exit;

  LPKValue := LProp.GetValue(aEntity).AsVariant;

  aContext.Query.SQL.Clear;
  aContext.Query.SQL.Add('SELECT COUNT(*) FROM ' + FTable + ' WHERE ' + FFKField + ' = :pValue');
  aContext.Query.Params.ParamByName('pValue').Value := LPKValue;
  aContext.Query.Open;
  try
    LCount := aContext.Query.DataSet.Fields[0].AsInteger;
  finally
    aContext.Query.DataSet.Close;
  end;

  if LCount > 0 then
    raise ESimpleGuardDelete.Create('Cannot delete: ' + IntToStr(LCount) +
      ' dependent records found in ' + FTable);
end;

function TSkillGuardDelete.Name: String;
begin
  Result := 'guard-delete';
end;

function TSkillGuardDelete.RunAt: TSkillRunAt;
begin
  Result := srBeforeDelete;
end;

{ TSkillHistory }

constructor TSkillHistory.Create(const aHistoryTable: String; aRunAt: TSkillRunAt);
begin
  FHistoryTable := aHistoryTable;
  FRunAt := aRunAt;
end;

destructor TSkillHistory.Destroy;
begin
  inherited;
end;

class function TSkillHistory.New(const aHistoryTable: String; aRunAt: TSkillRunAt): iSimpleSkill;
begin
  Result := Self.Create(aHistoryTable, aRunAt);
end;

function TSkillHistory.Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
var
  LRttiContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LPKProp: TRttiProperty;
  LPKValue: String;
  LValue: TValue;
  LValueStr: String;
  LSQL: String;
begin
  Result := Self;
  if (aEntity = nil) or (aContext.Query = nil) then
    Exit;

  LRttiContext := TRttiContext.Create;
  LType := LRttiContext.GetType(aEntity.ClassType);

  LPKProp := LType.GetPKField;
  if LPKProp = nil then
    Exit;

  LPKValue := LPKProp.GetValue(aEntity).AsVariant;

  LSQL := 'INSERT INTO ' + FHistoryTable +
    ' (ENTITY_NAME, RECORD_ID, FIELD_NAME, OLD_VALUE, OPERATION, CREATED_AT)' +
    ' VALUES (:pEntity, :pRecordId, :pField, :pOldValue, :pOperation, :pCreatedAt)';

  for LProp in LType.GetProperties do
  begin
    if LProp.IsIgnore then
      Continue;
    if not LProp.EhCampo then
      Continue;

    LValue := LProp.GetValue(aEntity);
    if LValue.Kind = tkFloat then
    begin
      if (LValue.TypeInfo = TypeInfo(TDateTime)) or
         (LValue.TypeInfo = TypeInfo(TDate)) or
         (LValue.TypeInfo = TypeInfo(TTime)) then
        LValueStr := DateTimeToStr(LValue.AsExtended)
      else
        LValueStr := FloatToStr(LValue.AsExtended);
    end
    else
      LValueStr := LValue.AsVariant;

    aContext.Query.SQL.Clear;
    aContext.Query.SQL.Add(LSQL);
    aContext.Query.Params.ParamByName('pEntity').Value := aContext.EntityName;
    aContext.Query.Params.ParamByName('pRecordId').Value := LPKValue;
    aContext.Query.Params.ParamByName('pField').Value := LProp.FieldName;
    aContext.Query.Params.ParamByName('pOldValue').Value := LValueStr;
    aContext.Query.Params.ParamByName('pOperation').Value := aContext.Operation;
    aContext.Query.Params.ParamByName('pCreatedAt').Value := Now;
    aContext.Query.ExecSQL;
  end;
end;

function TSkillHistory.Name: String;
begin
  Result := 'history';
end;

function TSkillHistory.RunAt: TSkillRunAt;
begin
  Result := FRunAt;
end;

{ TSkillValidate }

constructor TSkillValidate.Create(aRunAt: TSkillRunAt);
begin
  FRunAt := aRunAt;
end;

destructor TSkillValidate.Destroy;
begin
  inherited;
end;

class function TSkillValidate.New(aRunAt: TSkillRunAt): iSimpleSkill;
begin
  Result := Self.Create(aRunAt);
end;

function TSkillValidate.Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
begin
  Result := Self;
  if aEntity = nil then
    Exit;

  TSimpleValidator.Validate(aEntity);
end;

function TSkillValidate.Name: String;
begin
  Result := 'validate';
end;

function TSkillValidate.RunAt: TSkillRunAt;
begin
  Result := FRunAt;
end;

{ TSkillWebhook }

constructor TSkillWebhook.Create(const aURL: String; aRunAt: TSkillRunAt;
  const aAuthHeader: String);
begin
  FURL := aURL;
  FRunAt := aRunAt;
  FAuthHeader := aAuthHeader;
end;

destructor TSkillWebhook.Destroy;
begin
  inherited;
end;

class function TSkillWebhook.New(const aURL: String; aRunAt: TSkillRunAt;
  const aAuthHeader: String): iSimpleSkill;
begin
  Result := Self.Create(aURL, aRunAt, aAuthHeader);
end;

function TSkillWebhook.Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
var
  LClient: THTTPClient;
  LPayload: TJSONObject;
  LEntityJSON: TJSONObject;
  LBody: TStringStream;
begin
  Result := Self;
  if aEntity = nil then
    Exit;

  LClient := THTTPClient.Create;
  try
    try
      LEntityJSON := TSimpleSerializer.EntityToJSON<TObject>(aEntity);
      try
        LPayload := TJSONObject.Create;
        try
          LPayload.AddPair('entity', aContext.EntityName);
          LPayload.AddPair('operation', aContext.Operation);
          LPayload.AddPair('timestamp', DateToISO8601(Now));
          LPayload.AddPair('data', LEntityJSON.Clone as TJSONObject);

          LBody := TStringStream.Create(LPayload.ToJSON, TEncoding.UTF8);
          try
            LClient.ContentType := 'application/json';
            if FAuthHeader <> '' then
              LClient.CustomHeaders['Authorization'] := FAuthHeader;
            LClient.ConnectionTimeout := 5000;
            LClient.ResponseTimeout := 10000;
            LClient.Post(FURL, LBody);
          finally
            LBody.Free;
          end;
        finally
          LPayload.Free;
        end;
      finally
        LEntityJSON.Free;
      end;
    except
      on E: Exception do
      begin
        {$IFDEF MSWINDOWS}
        OutputDebugString(PChar('[Skill:Webhook] Error: ' + E.Message));
        {$ENDIF}
        {$IFDEF CONSOLE}
        Writeln('[Skill:Webhook] Error: ', E.Message);
        {$ENDIF}
      end;
    end;
  finally
    LClient.Free;
  end;
end;

function TSkillWebhook.Name: String;
begin
  Result := 'webhook';
end;

function TSkillWebhook.RunAt: TSkillRunAt;
begin
  Result := FRunAt;
end;

{ TSkillSequence }

constructor TSkillSequence.Create(const aFieldName, aControlTable, aSerie: String);
begin
  FFieldName := aFieldName;
  FControlTable := aControlTable;
  FSerie := aSerie;
end;

destructor TSkillSequence.Destroy;
begin
  inherited;
end;

class function TSkillSequence.New(const aFieldName, aControlTable, aSerie: String): iSimpleSkill;
begin
  Result := Self.Create(aFieldName, aControlTable, aSerie);
end;

function TSkillSequence.Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LNextNumber: Integer;
begin
  Result := Self;
  if (aEntity = nil) or (aContext.Query = nil) then
    Exit;

  LContext := TRttiContext.Create;
  LType := LContext.GetType(aEntity.ClassType);
  LProp := LType.GetProperty(FFieldName);
  if LProp = nil then
    Exit;

  // Try to get current number
  aContext.Query.SQL.Clear;
  aContext.Query.SQL.Add('SELECT ULTIMO_NUMERO FROM ' + FControlTable + ' WHERE SERIE = :pSerie');
  aContext.Query.Params.ParamByName('pSerie').Value := FSerie;
  aContext.Query.Open;
  try
    if aContext.Query.DataSet.IsEmpty then
    begin
      aContext.Query.DataSet.Close;
      // Insert first record
      LNextNumber := 1;
      aContext.Query.SQL.Clear;
      aContext.Query.SQL.Add('INSERT INTO ' + FControlTable + ' (SERIE, ULTIMO_NUMERO) VALUES (:pSerie, :pNumero)');
      aContext.Query.Params.ParamByName('pSerie').Value := FSerie;
      aContext.Query.Params.ParamByName('pNumero').Value := LNextNumber;
      aContext.Query.ExecSQL;
    end
    else
    begin
      LNextNumber := aContext.Query.DataSet.Fields[0].AsInteger + 1;
      aContext.Query.DataSet.Close;
      // Update existing record
      aContext.Query.SQL.Clear;
      aContext.Query.SQL.Add('UPDATE ' + FControlTable + ' SET ULTIMO_NUMERO = :pNumero WHERE SERIE = :pSerie');
      aContext.Query.Params.ParamByName('pNumero').Value := LNextNumber;
      aContext.Query.Params.ParamByName('pSerie').Value := FSerie;
      aContext.Query.ExecSQL;
    end;
  except
    on E: Exception do
    begin
      aContext.Query.DataSet.Close;
      raise;
    end;
  end;

  LProp.SetValue(aEntity, TValue.From<Integer>(LNextNumber));
end;

function TSkillSequence.Name: String;
begin
  Result := 'sequence';
end;

function TSkillSequence.RunAt: TSkillRunAt;
begin
  Result := srBeforeInsert;
end;

end.
