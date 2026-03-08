unit SimpleHorseRouter;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections,
  Horse, SimpleInterface, SimpleDAO, SimpleRTTI, SimpleSerializer;

type
  TEntityCallback = reference to procedure(aEntity: TObject; var aContinue: Boolean);
  TEntityAfterCallback = reference to procedure(aEntity: TObject);
  TDeleteCallback = reference to procedure(aId: string; var aContinue: Boolean);

  TSimpleHorseRouterConfig = class
  private
    FOnBeforeInsert: TEntityCallback;
    FOnAfterInsert: TEntityAfterCallback;
    FOnBeforeUpdate: TEntityCallback;
    FOnBeforeDelete: TDeleteCallback;
  public
    function OnBeforeInsert(aProc: TEntityCallback): TSimpleHorseRouterConfig;
    function OnAfterInsert(aProc: TEntityAfterCallback): TSimpleHorseRouterConfig;
    function OnBeforeUpdate(aProc: TEntityCallback): TSimpleHorseRouterConfig;
    function OnBeforeDelete(aProc: TDeleteCallback): TSimpleHorseRouterConfig;
  end;

  TSimpleHorseRouter = class
  public
    class function RegisterEntity<T: class, constructor>(
      aApp: THorse; aQuery: iSimpleQuery; aPath: string = ''
    ): TSimpleHorseRouterConfig;
  end;

implementation

{ TSimpleHorseRouterConfig }

function TSimpleHorseRouterConfig.OnBeforeInsert(aProc: TEntityCallback): TSimpleHorseRouterConfig;
begin
  FOnBeforeInsert := aProc;
  Result := Self;
end;

function TSimpleHorseRouterConfig.OnAfterInsert(aProc: TEntityAfterCallback): TSimpleHorseRouterConfig;
begin
  FOnAfterInsert := aProc;
  Result := Self;
end;

function TSimpleHorseRouterConfig.OnBeforeUpdate(aProc: TEntityCallback): TSimpleHorseRouterConfig;
begin
  FOnBeforeUpdate := aProc;
  Result := Self;
end;

function TSimpleHorseRouterConfig.OnBeforeDelete(aProc: TDeleteCallback): TSimpleHorseRouterConfig;
begin
  FOnBeforeDelete := aProc;
  Result := Self;
end;

{ TSimpleHorseRouter }

class function TSimpleHorseRouter.RegisterEntity<T>(
  aApp: THorse; aQuery: iSimpleQuery; aPath: string): TSimpleHorseRouterConfig;
var
  LConfig: TSimpleHorseRouterConfig;
  LPath: string;
  LTableName: string;
begin
  LConfig := TSimpleHorseRouterConfig.Create;
  Result := LConfig;

  if aPath <> '' then
    LPath := aPath
  else
  begin
    TSimpleRTTI<T>.New(nil).TableName(LTableName);
    LPath := '/' + LowerCase(LTableName);
  end;

  { GET /path - List all with optional skip/take }
  aApp.Get(LPath,
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      LDAO: iSimpleDAO<T>;
      LList: TObjectList<T>;
      LJSONArray: TJSONArray;
      LResult: TJSONObject;
      LSkipStr, LTakeStr: string;
      LSkip, LTake: Integer;
    begin
      try
        LDAO := TSimpleDAO<T>.New(aQuery);
        LList := TObjectList<T>.Create;
        try
          LSkipStr := Req.Query['skip'];
          LTakeStr := Req.Query['take'];

          if (LSkipStr <> '') or (LTakeStr <> '') then
          begin
            LSkip := 0;
            LTake := 0;
            if LSkipStr <> '' then
              LSkip := StrToIntDef(LSkipStr, 0);
            if LTakeStr <> '' then
              LTake := StrToIntDef(LTakeStr, 0);

            LDAO.SQL
              .Skip(LSkip)
              .Take(LTake)
              .&End
              .Find(LList);
          end
          else
            LDAO.Find(LList);

          LJSONArray := TSimpleSerializer.EntityListToJSONArray<T>(LList);
          LResult := TJSONObject.Create;
          LResult.AddPair('data', LJSONArray);
          LResult.AddPair('count', TJSONNumber.Create(LList.Count));

          Res.Send<TJSONObject>(LResult).Status(200);
        finally
          LList.Free;
        end;
      except
        on E: Exception do
          Res.Send<TJSONObject>(
            TJSONObject.Create.AddPair('error', E.Message)
          ).Status(500);
      end;
    end
  );

  { GET /path/:id - Find by primary key }
  aApp.Get(LPath + '/:id',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      LDAO: iSimpleDAO<T>;
      LEntity: T;
      LId: Integer;
      LJSON: TJSONObject;
    begin
      try
        LId := StrToInt(Req.Params['id']);
        LDAO := TSimpleDAO<T>.New(aQuery);
        LEntity := LDAO.Find(LId);
        try
          if LEntity = nil then
          begin
            Res.Send<TJSONObject>(
              TJSONObject.Create.AddPair('error', 'Not found')
            ).Status(404);
            Exit;
          end;

          LJSON := TSimpleSerializer.EntityToJSON<T>(LEntity);
          Res.Send<TJSONObject>(LJSON).Status(200);
        finally
          LEntity.Free;
        end;
      except
        on E: Exception do
          Res.Send<TJSONObject>(
            TJSONObject.Create.AddPair('error', E.Message)
          ).Status(500);
      end;
    end
  );

  { POST /path - Insert entity from body JSON }
  aApp.Post(LPath,
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      LDAO: iSimpleDAO<T>;
      LEntity: T;
      LJSONBody: TJSONObject;
      LJSONResult: TJSONObject;
      LContinue: Boolean;
    begin
      try
        LJSONBody := TJSONObject.ParseJSONValue(Req.Body) as TJSONObject;
        try
          LEntity := TSimpleSerializer.JSONToEntity<T>(LJSONBody);
        finally
          LJSONBody.Free;
        end;

        try
          if Assigned(LConfig.FOnBeforeInsert) then
          begin
            LContinue := True;
            LConfig.FOnBeforeInsert(LEntity, LContinue);
            if not LContinue then
            begin
              Res.Send<TJSONObject>(
                TJSONObject.Create.AddPair('error', 'Operation cancelled')
              ).Status(400);
              Exit;
            end;
          end;

          LDAO := TSimpleDAO<T>.New(aQuery);
          LDAO.Insert(LEntity);

          if Assigned(LConfig.FOnAfterInsert) then
            LConfig.FOnAfterInsert(LEntity);

          LJSONResult := TSimpleSerializer.EntityToJSON<T>(LEntity);
          Res.Send<TJSONObject>(LJSONResult).Status(201);
        finally
          LEntity.Free;
        end;
      except
        on E: Exception do
          Res.Send<TJSONObject>(
            TJSONObject.Create.AddPair('error', E.Message)
          ).Status(500);
      end;
    end
  );

  { PUT /path/:id - Update entity from body JSON }
  aApp.Put(LPath + '/:id',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      LDAO: iSimpleDAO<T>;
      LEntity: T;
      LJSONBody: TJSONObject;
      LJSONResult: TJSONObject;
      LContinue: Boolean;
    begin
      try
        LJSONBody := TJSONObject.ParseJSONValue(Req.Body) as TJSONObject;
        try
          LEntity := TSimpleSerializer.JSONToEntity<T>(LJSONBody);
        finally
          LJSONBody.Free;
        end;

        try
          if Assigned(LConfig.FOnBeforeUpdate) then
          begin
            LContinue := True;
            LConfig.FOnBeforeUpdate(LEntity, LContinue);
            if not LContinue then
            begin
              Res.Send<TJSONObject>(
                TJSONObject.Create.AddPair('error', 'Operation cancelled')
              ).Status(400);
              Exit;
            end;
          end;

          LDAO := TSimpleDAO<T>.New(aQuery);
          LDAO.Update(LEntity);

          LJSONResult := TSimpleSerializer.EntityToJSON<T>(LEntity);
          Res.Send<TJSONObject>(LJSONResult).Status(200);
        finally
          LEntity.Free;
        end;
      except
        on E: Exception do
          Res.Send<TJSONObject>(
            TJSONObject.Create.AddPair('error', E.Message)
          ).Status(500);
      end;
    end
  );

  { DELETE /path/:id - Delete by primary key }
  aApp.Delete(LPath + '/:id',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      LDAO: iSimpleDAO<T>;
      LId: string;
      LPK: string;
      LContinue: Boolean;
    begin
      try
        LId := Req.Params['id'];

        if Assigned(LConfig.FOnBeforeDelete) then
        begin
          LContinue := True;
          LConfig.FOnBeforeDelete(LId, LContinue);
          if not LContinue then
          begin
            Res.Send<TJSONObject>(
              TJSONObject.Create.AddPair('error', 'Operation cancelled')
            ).Status(400);
            Exit;
          end;
        end;

        TSimpleRTTI<T>.New(nil).PrimaryKey(LPK);

        LDAO := TSimpleDAO<T>.New(aQuery);
        LDAO.Delete(LPK, LId);

        Res.Status(204);
      except
        on E: Exception do
          Res.Send<TJSONObject>(
            TJSONObject.Create.AddPair('error', E.Message)
          ).Status(500);
      end;
    end
  );
end;

end.
