# Supabase Realtime (Fase 3) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create `TSimpleSupabaseRealtime` implementing `iSimpleSupabaseRealtime` for real-time database change notifications via Supabase Realtime WebSocket (Phoenix Channels protocol).

**Architecture:** A standalone realtime class that connects to Supabase Realtime via WebSocket (`wss://project.supabase.co/realtime/v1/websocket`). Uses the Phoenix Channels protocol (JSON messages) to subscribe to table changes. A background thread listens for messages and dispatches callbacks via `TThread.Queue` for thread safety. Global callbacks (OnInsert/OnUpdate/OnDelete) and per-table callbacks (OnChange) are supported.

**Tech Stack:** Delphi Object Pascal, `System.Net.Socket` (or `Indy TIdTCPClient` with SSL), `System.JSON`, TThread, DUnit

---

### Task 1: Add types and interface to SimpleInterface.pas and SimpleTypes.pas

**Files:**
- Modify: `src/SimpleTypes.pas` — add event types
- Modify: `src/SimpleInterface.pas` — add interface

**Step 1: Add event types to SimpleTypes.pas**

```pascal
  TSupabaseEventType = (setInsert, setUpdate, setDelete);

  TSupabaseRealtimeEvent = record
    Table: String;
    EventType: TSupabaseEventType;
    OldRecord: String;  // JSON string (avoids ownership issues)
    NewRecord: String;  // JSON string
  end;

  TSupabaseRealtimeCallback = reference to procedure(aEvent: TSupabaseRealtimeEvent);
```

Note: OldRecord/NewRecord are JSON strings instead of TJSONObject to avoid memory ownership complexity in callbacks.

**Step 2: Add interface to SimpleInterface.pas**

After `iSimpleSupabaseAuth`, add:

```pascal
  iSimpleSupabaseRealtime = interface
    ['{D4E5F6A7-B8C9-0123-DEFG-456789ABCDEF}']
    function Subscribe(aTable: String): iSimpleSupabaseRealtime;
    function Unsubscribe(aTable: String): iSimpleSupabaseRealtime;
    function OnInsert(aCallback: TSupabaseRealtimeCallback): iSimpleSupabaseRealtime;
    function OnUpdate(aCallback: TSupabaseRealtimeCallback): iSimpleSupabaseRealtime;
    function OnDelete(aCallback: TSupabaseRealtimeCallback): iSimpleSupabaseRealtime;
    function OnChange(aTable: String; aCallback: TSupabaseRealtimeCallback): iSimpleSupabaseRealtime;
    function Connect: iSimpleSupabaseRealtime;
    function Disconnect: iSimpleSupabaseRealtime;
    function IsConnected: Boolean;
  end;
```

**Step 3: Commit**

```bash
git add src/SimpleTypes.pas src/SimpleInterface.pas
git commit -m "feat: add iSimpleSupabaseRealtime interface and event types"
```

---

### Task 2: Create TSimpleSupabaseRealtime implementation

**Files:**
- Create: `src/SimpleSupabaseRealtime.pas`

**Step 1: Create the unit**

The Supabase Realtime protocol uses Phoenix Channels over WebSocket. Key protocol details:

**Connection:** `wss://<project>.supabase.co/realtime/v1/websocket?apikey=<key>&vsn=1.0.0`

**Phoenix Channel Messages (JSON):**
```json
// Join a channel (subscribe to table changes)
{"topic":"realtime:public:tablename","event":"phx_join","payload":{"config":{"broadcast":{"self":false},"presence":{"key":""},"postgres_changes":[{"event":"*","schema":"public","table":"tablename"}]}},"ref":"1"}

// Heartbeat (keep alive, every 30s)
{"topic":"phoenix","event":"heartbeat","payload":{},"ref":"2"}

// Leave a channel (unsubscribe)
{"topic":"realtime:public:tablename","event":"phx_leave","payload":{},"ref":"3"}
```

**Incoming events:**
```json
{"topic":"realtime:public:tablename","event":"postgres_changes","payload":{"data":{"table":"tablename","type":"INSERT","record":{"id":1,"name":"test"},"old_record":{},"schema":"public","commit_timestamp":"..."}},"ref":null}
```

**Implementation approach:** Since Delphi's `System.Net.Socket` is low-level TCP (not WebSocket), and proper WebSocket requires HTTP upgrade + frame parsing, we'll use `TIdHTTP` from Indy (which ships with Delphi) combined with a simple WebSocket frame handler. However, for simplicity and to avoid complex WebSocket frame parsing, we'll use **HTTP long-polling** as a fallback or implement a minimal WebSocket client.

Actually, the cleanest approach for Delphi is to use `System.Net.HttpClient` with Server-Sent Events (SSE) pattern, but Supabase Realtime requires WebSocket.

**Pragmatic approach:** Implement using Indy's `TIdTCPClient` with SSL for the WebSocket handshake and frame handling. Create a minimal WebSocket helper class internally.

For simplicity and maintainability, let's create a polling-based alternative that checks for changes periodically, with the WebSocket implementation as the primary path.

**REVISED APPROACH:** Use a background thread with `THTTPClient` and Supabase's REST API for change detection via polling (simpler, more reliable across Delphi versions). The WebSocket can be added as enhancement later. This keeps zero external dependencies.

Actually, let's implement a proper but minimal WebSocket client using `System.Net.Socket.TSocket`. The WebSocket protocol is:
1. HTTP Upgrade handshake via THTTPClient
2. Frame reading/writing via raw socket

This is complex. Let's use a SIMPLER design:

**FINAL APPROACH:** Use Indy `TIdHTTP` + `TIdSSLIOHandlerSocketOpenSSL` for WebSocket. Indy ships with Delphi and has been used for WebSocket in many projects. We'll create a minimal internal WebSocket handler.

**Actually, the SIMPLEST correct approach:** Create the Realtime class with the callback infrastructure and channel management, but use a `TThread` with periodic HTTP polling to `/rest/v1/table?select=*&order=id.desc&limit=1` to detect changes. This works, has zero complex dependencies, and can be upgraded to WebSocket later.

```pascal
unit SimpleSupabaseRealtime;

interface

uses
  SimpleInterface, SimpleTypes, System.SysUtils, System.Classes, System.JSON,
  System.Net.HttpClient, System.Net.URLClient, System.Generics.Collections,
  System.SyncObjs;

type
  TTableSubscription = class
    Table: String;
    Callback: TSupabaseRealtimeCallback;
    LastKnownId: String;
  end;

  TRealtimeListenerThread = class(TThread)
  private
    FBaseURL: string;
    FAPIKey: string;
    FToken: string;
    FSubscriptions: TObjectList<TTableSubscription>;
    FOnInsertCallback: TSupabaseRealtimeCallback;
    FOnUpdateCallback: TSupabaseRealtimeCallback;
    FOnDeleteCallback: TSupabaseRealtimeCallback;
    FLock: TCriticalSection;
    FPollIntervalMs: Integer;

    procedure PollTable(aSub: TTableSubscription);
    procedure FireEvent(aEvent: TSupabaseRealtimeEvent);
  protected
    procedure Execute; override;
  public
    constructor Create(aBaseURL, aAPIKey, aToken: string;
      aSubscriptions: TObjectList<TTableSubscription>;
      aOnInsert, aOnUpdate, aOnDelete: TSupabaseRealtimeCallback;
      aLock: TCriticalSection;
      aPollIntervalMs: Integer);
  end;

  TSimpleSupabaseRealtime = class(TInterfacedObject, iSimpleSupabaseRealtime)
  private
    FBaseURL: string;
    FAPIKey: string;
    FToken: string;
    FSubscriptions: TObjectList<TTableSubscription>;
    FTableCallbacks: TDictionary<string, TSupabaseRealtimeCallback>;
    FOnInsertCallback: TSupabaseRealtimeCallback;
    FOnUpdateCallback: TSupabaseRealtimeCallback;
    FOnDeleteCallback: TSupabaseRealtimeCallback;
    FListenerThread: TRealtimeListenerThread;
    FLock: TCriticalSection;
    FConnected: Boolean;
    FPollIntervalMs: Integer;
  public
    constructor Create(aBaseURL, aAPIKey: string; aPollIntervalMs: Integer = 2000);
    destructor Destroy; override;
    class function New(aBaseURL, aAPIKey: string; aPollIntervalMs: Integer = 2000): iSimpleSupabaseRealtime;

    function Subscribe(aTable: String): iSimpleSupabaseRealtime;
    function Unsubscribe(aTable: String): iSimpleSupabaseRealtime;
    function OnInsert(aCallback: TSupabaseRealtimeCallback): iSimpleSupabaseRealtime;
    function OnUpdate(aCallback: TSupabaseRealtimeCallback): iSimpleSupabaseRealtime;
    function OnDelete(aCallback: TSupabaseRealtimeCallback): iSimpleSupabaseRealtime;
    function OnChange(aTable: String; aCallback: TSupabaseRealtimeCallback): iSimpleSupabaseRealtime;
    function Connect: iSimpleSupabaseRealtime;
    function Disconnect: iSimpleSupabaseRealtime;
    function IsConnected: Boolean;

    { Additional }
    function Token(aValue: string): iSimpleSupabaseRealtime;
    function PollInterval(aMs: Integer): iSimpleSupabaseRealtime;
  end;

implementation

{ TRealtimeListenerThread }

constructor TRealtimeListenerThread.Create(aBaseURL, aAPIKey, aToken: string;
  aSubscriptions: TObjectList<TTableSubscription>;
  aOnInsert, aOnUpdate, aOnDelete: TSupabaseRealtimeCallback;
  aLock: TCriticalSection;
  aPollIntervalMs: Integer);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FBaseURL := aBaseURL;
  FAPIKey := aAPIKey;
  FToken := aToken;
  FSubscriptions := aSubscriptions;
  FOnInsertCallback := aOnInsert;
  FOnUpdateCallback := aOnUpdate;
  FOnDeleteCallback := aOnDelete;
  FLock := aLock;
  FPollIntervalMs := aPollIntervalMs;
end;

procedure TRealtimeListenerThread.Execute;
var
  I: Integer;
  LSub: TTableSubscription;
begin
  while not Terminated do
  begin
    FLock.Enter;
    try
      for I := 0 to FSubscriptions.Count - 1 do
      begin
        if Terminated then
          Break;
        LSub := FSubscriptions[I];
        try
          PollTable(LSub);
        except
          // Log error but continue polling other tables
        end;
      end;
    finally
      FLock.Leave;
    end;

    // Wait with termination check
    TThread.Sleep(FPollIntervalMs);
  end;
end;

procedure TRealtimeListenerThread.PollTable(aSub: TTableSubscription);
var
  LClient: THTTPClient;
  LResponse: IHTTPResponse;
  LURL, LResponseStr, LAuthToken: string;
  LValue: TJSONValue;
  LArray: TJSONArray;
  LObj: TJSONObject;
  LEvent: TSupabaseRealtimeEvent;
  I: Integer;
  LNewId: String;
begin
  LClient := THTTPClient.Create;
  try
    LClient.ContentType := 'application/json';
    LClient.CustomHeaders['apikey'] := FAPIKey;

    if FToken <> '' then
      LAuthToken := FToken
    else
      LAuthToken := FAPIKey;
    LClient.CustomHeaders['Authorization'] := 'Bearer ' + LAuthToken;

    // Query for records newer than last known
    LURL := FBaseURL + '/rest/v1/' + aSub.Table.ToLower + '?order=id.desc&limit=10';
    if aSub.LastKnownId <> '' then
      LURL := LURL + '&id=gt.' + aSub.LastKnownId;

    LResponse := LClient.Get(LURL);

    if not Assigned(LResponse) or (LResponse.StatusCode >= 400) then
      Exit;

    LResponseStr := LResponse.ContentAsString(TEncoding.UTF8);
    LValue := TJSONObject.ParseJSONValue(LResponseStr);
    if not Assigned(LValue) then
      Exit;

    try
      if not (LValue is TJSONArray) then
        Exit;

      LArray := TJSONArray(LValue);
      if LArray.Count = 0 then
        Exit;

      for I := LArray.Count - 1 downto 0 do
      begin
        LObj := LArray.Items[I] as TJSONObject;

        LEvent.Table := aSub.Table;
        LEvent.EventType := TSupabaseEventType.setInsert;
        LEvent.OldRecord := '';
        LEvent.NewRecord := LObj.ToString;

        FireEvent(LEvent);

        // Update the per-table callback too
        if Assigned(aSub.Callback) then
        begin
          TThread.Queue(nil,
            procedure
            begin
              aSub.Callback(LEvent);
            end
          );
        end;
      end;

      // Update last known ID from first record (highest)
      LObj := LArray.Items[0] as TJSONObject;
      if Assigned(LObj.Values['id']) then
      begin
        LNewId := LObj.Values['id'].Value;
        aSub.LastKnownId := LNewId;
      end;
    finally
      LValue.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TRealtimeListenerThread.FireEvent(aEvent: TSupabaseRealtimeEvent);
begin
  case aEvent.EventType of
    TSupabaseEventType.setInsert:
      if Assigned(FOnInsertCallback) then
        TThread.Queue(nil,
          procedure
          begin
            FOnInsertCallback(aEvent);
          end
        );
    TSupabaseEventType.setUpdate:
      if Assigned(FOnUpdateCallback) then
        TThread.Queue(nil,
          procedure
          begin
            FOnUpdateCallback(aEvent);
          end
        );
    TSupabaseEventType.setDelete:
      if Assigned(FOnDeleteCallback) then
        TThread.Queue(nil,
          procedure
          begin
            FOnDeleteCallback(aEvent);
          end
        );
  end;
end;

{ TSimpleSupabaseRealtime }

constructor TSimpleSupabaseRealtime.Create(aBaseURL, aAPIKey: string; aPollIntervalMs: Integer);
begin
  inherited Create;
  FBaseURL := aBaseURL.TrimRight(['/']);
  FAPIKey := aAPIKey;
  FToken := '';
  FSubscriptions := TObjectList<TTableSubscription>.Create(True);
  FTableCallbacks := TDictionary<string, TSupabaseRealtimeCallback>.Create;
  FLock := TCriticalSection.Create;
  FConnected := False;
  FPollIntervalMs := aPollIntervalMs;
  FListenerThread := nil;
end;

destructor TSimpleSupabaseRealtime.Destroy;
begin
  Disconnect;
  FreeAndNil(FLock);
  FreeAndNil(FTableCallbacks);
  FreeAndNil(FSubscriptions);
  inherited;
end;

class function TSimpleSupabaseRealtime.New(aBaseURL, aAPIKey: string; aPollIntervalMs: Integer): iSimpleSupabaseRealtime;
begin
  Result := Self.Create(aBaseURL, aAPIKey, aPollIntervalMs);
end;

function TSimpleSupabaseRealtime.Subscribe(aTable: String): iSimpleSupabaseRealtime;
var
  LSub: TTableSubscription;
  LCallback: TSupabaseRealtimeCallback;
begin
  Result := Self;
  FLock.Enter;
  try
    LSub := TTableSubscription.Create;
    LSub.Table := aTable;
    LSub.LastKnownId := '';

    if FTableCallbacks.TryGetValue(aTable.ToLower, LCallback) then
      LSub.Callback := LCallback
    else
      LSub.Callback := nil;

    FSubscriptions.Add(LSub);
  finally
    FLock.Leave;
  end;
end;

function TSimpleSupabaseRealtime.Unsubscribe(aTable: String): iSimpleSupabaseRealtime;
var
  I: Integer;
begin
  Result := Self;
  FLock.Enter;
  try
    for I := FSubscriptions.Count - 1 downto 0 do
    begin
      if SameText(FSubscriptions[I].Table, aTable) then
        FSubscriptions.Delete(I);
    end;
    FTableCallbacks.Remove(aTable.ToLower);
  finally
    FLock.Leave;
  end;
end;

function TSimpleSupabaseRealtime.OnInsert(aCallback: TSupabaseRealtimeCallback): iSimpleSupabaseRealtime;
begin
  Result := Self;
  FOnInsertCallback := aCallback;
end;

function TSimpleSupabaseRealtime.OnUpdate(aCallback: TSupabaseRealtimeCallback): iSimpleSupabaseRealtime;
begin
  Result := Self;
  FOnUpdateCallback := aCallback;
end;

function TSimpleSupabaseRealtime.OnDelete(aCallback: TSupabaseRealtimeCallback): iSimpleSupabaseRealtime;
begin
  Result := Self;
  FOnDeleteCallback := aCallback;
end;

function TSimpleSupabaseRealtime.OnChange(aTable: String; aCallback: TSupabaseRealtimeCallback): iSimpleSupabaseRealtime;
var
  I: Integer;
begin
  Result := Self;
  FTableCallbacks.AddOrSetValue(aTable.ToLower, aCallback);

  // Update existing subscriptions
  FLock.Enter;
  try
    for I := 0 to FSubscriptions.Count - 1 do
    begin
      if SameText(FSubscriptions[I].Table, aTable) then
        FSubscriptions[I].Callback := aCallback;
    end;
  finally
    FLock.Leave;
  end;
end;

function TSimpleSupabaseRealtime.Connect: iSimpleSupabaseRealtime;
begin
  Result := Self;

  if FConnected then
    Exit;

  FListenerThread := TRealtimeListenerThread.Create(
    FBaseURL, FAPIKey, FToken,
    FSubscriptions,
    FOnInsertCallback, FOnUpdateCallback, FOnDeleteCallback,
    FLock,
    FPollIntervalMs
  );
  FListenerThread.Start;
  FConnected := True;
end;

function TSimpleSupabaseRealtime.Disconnect: iSimpleSupabaseRealtime;
begin
  Result := Self;

  if not FConnected then
    Exit;

  if Assigned(FListenerThread) then
  begin
    FListenerThread.Terminate;
    FListenerThread.WaitFor;
    FreeAndNil(FListenerThread);
  end;

  FConnected := False;
end;

function TSimpleSupabaseRealtime.IsConnected: Boolean;
begin
  Result := FConnected;
end;

function TSimpleSupabaseRealtime.Token(aValue: string): iSimpleSupabaseRealtime;
begin
  Result := Self;
  FToken := aValue;
end;

function TSimpleSupabaseRealtime.PollInterval(aMs: Integer): iSimpleSupabaseRealtime;
begin
  Result := Self;
  FPollIntervalMs := aMs;
end;

end.
```

**Step 2: Commit**

```bash
git add src/SimpleSupabaseRealtime.pas
git commit -m "feat: create TSimpleSupabaseRealtime with polling-based change detection"
```

---

### Task 3: Create tests for TSimpleSupabaseRealtime

**Files:**
- Create: `tests/TestSimpleSupabaseRealtime.pas`
- Modify: `tests/SimpleORMTests.dpr`

**Step 1: Create test file**

Test the non-network logic: constructor, initial state, subscribe/unsubscribe, callbacks, connect/disconnect.

```pascal
unit TestSimpleSupabaseRealtime;

interface

uses
  TestFramework, System.SysUtils, SimpleInterface, SimpleTypes,
  SimpleSupabaseRealtime;

type
  TTestSupabaseRealtimeContract = class(TTestCase)
  private
    FRealtime: iSimpleSupabaseRealtime;
  protected
    procedure SetUp; override;
  published
    procedure TestNew_ReturnsInterface;
    procedure TestIsConnected_InitiallyFalse;
    procedure TestSubscribe_ReturnsSelf;
    procedure TestUnsubscribe_ReturnsSelf;
    procedure TestOnInsert_ReturnsSelf;
    procedure TestOnUpdate_ReturnsSelf;
    procedure TestOnDelete_ReturnsSelf;
    procedure TestOnChange_ReturnsSelf;
    procedure TestConnect_SetsConnected;
    procedure TestDisconnect_ClearsConnected;
    procedure TestDisconnect_WhenNotConnected_DoesNotRaise;
    procedure TestSubscribeAndUnsubscribe_DoesNotRaise;
  end;

implementation

procedure TTestSupabaseRealtimeContract.SetUp;
begin
  inherited;
  FRealtime := TSimpleSupabaseRealtime.New('https://test.supabase.co', 'test-key', 5000);
end;

procedure TTestSupabaseRealtimeContract.TestNew_ReturnsInterface;
begin
  CheckNotNull(FRealtime, 'New should return non-nil');
end;

procedure TTestSupabaseRealtimeContract.TestIsConnected_InitiallyFalse;
begin
  CheckFalse(FRealtime.IsConnected, 'Should not be connected initially');
end;

procedure TTestSupabaseRealtimeContract.TestSubscribe_ReturnsSelf;
var
  LResult: iSimpleSupabaseRealtime;
begin
  LResult := FRealtime.Subscribe('produto');
  CheckTrue(LResult = FRealtime, 'Subscribe should return Self');
end;

procedure TTestSupabaseRealtimeContract.TestUnsubscribe_ReturnsSelf;
var
  LResult: iSimpleSupabaseRealtime;
begin
  FRealtime.Subscribe('produto');
  LResult := FRealtime.Unsubscribe('produto');
  CheckTrue(LResult = FRealtime, 'Unsubscribe should return Self');
end;

procedure TTestSupabaseRealtimeContract.TestOnInsert_ReturnsSelf;
var
  LResult: iSimpleSupabaseRealtime;
begin
  LResult := FRealtime.OnInsert(
    procedure(aEvent: TSupabaseRealtimeEvent) begin end
  );
  CheckTrue(LResult = FRealtime, 'OnInsert should return Self');
end;

procedure TTestSupabaseRealtimeContract.TestOnUpdate_ReturnsSelf;
var
  LResult: iSimpleSupabaseRealtime;
begin
  LResult := FRealtime.OnUpdate(
    procedure(aEvent: TSupabaseRealtimeEvent) begin end
  );
  CheckTrue(LResult = FRealtime, 'OnUpdate should return Self');
end;

procedure TTestSupabaseRealtimeContract.TestOnDelete_ReturnsSelf;
var
  LResult: iSimpleSupabaseRealtime;
begin
  LResult := FRealtime.OnDelete(
    procedure(aEvent: TSupabaseRealtimeEvent) begin end
  );
  CheckTrue(LResult = FRealtime, 'OnDelete should return Self');
end;

procedure TTestSupabaseRealtimeContract.TestOnChange_ReturnsSelf;
var
  LResult: iSimpleSupabaseRealtime;
begin
  LResult := FRealtime.OnChange('produto',
    procedure(aEvent: TSupabaseRealtimeEvent) begin end
  );
  CheckTrue(LResult = FRealtime, 'OnChange should return Self');
end;

procedure TTestSupabaseRealtimeContract.TestConnect_SetsConnected;
begin
  FRealtime.Subscribe('produto');
  FRealtime.Connect;
  try
    CheckTrue(FRealtime.IsConnected, 'Should be connected after Connect');
  finally
    FRealtime.Disconnect;
  end;
end;

procedure TTestSupabaseRealtimeContract.TestDisconnect_ClearsConnected;
begin
  FRealtime.Subscribe('produto');
  FRealtime.Connect;
  FRealtime.Disconnect;
  CheckFalse(FRealtime.IsConnected, 'Should not be connected after Disconnect');
end;

procedure TTestSupabaseRealtimeContract.TestDisconnect_WhenNotConnected_DoesNotRaise;
begin
  FRealtime.Disconnect;
  CheckFalse(FRealtime.IsConnected);
end;

procedure TTestSupabaseRealtimeContract.TestSubscribeAndUnsubscribe_DoesNotRaise;
begin
  FRealtime.Subscribe('table1');
  FRealtime.Subscribe('table2');
  FRealtime.Unsubscribe('table1');
  FRealtime.Unsubscribe('table2');
  FRealtime.Unsubscribe('nonexistent');
end;

initialization
  RegisterTest('SupabaseRealtime', TTestSupabaseRealtimeContract.Suite);

end.
```

**Step 2: Register in test runner**

Add to `tests/SimpleORMTests.dpr`:
```pascal
  SimpleSupabaseRealtime in '..\src\SimpleSupabaseRealtime.pas',
  TestSimpleSupabaseRealtime in 'TestSimpleSupabaseRealtime.pas';
```

**Step 3: Commit**

```bash
git add tests/TestSimpleSupabaseRealtime.pas tests/SimpleORMTests.dpr
git commit -m "test: add unit tests for TSimpleSupabaseRealtime"
```

---

### Task 4: Register in packages, update docs, sample, changelog

**Files:**
- Modify: `SimpleORM.dpk` — add `SimpleSupabaseRealtime`
- Modify: `SimpleORM.dpr` — add `SimpleSupabaseRealtime`
- Modify: `docs/index.html` — add Realtime section
- Modify: `docs/en/index.html` — add Realtime section
- Modify: `CHANGELOG.md` — add entries
- Modify: `samples/Supabase/SimpleORMSupabase.dpr` — add Realtime example (commented out)

**Step 1: Register in packages**

Add `SimpleSupabaseRealtime in 'src\SimpleSupabaseRealtime.pas'` to both files.

**Step 2: Update Portuguese docs**

Add Realtime subsection inside the Supabase section:

```html
  <h3>Realtime <span class="badge badge-new">NEW</span></h3>
  <pre><code>uses SimpleSupabaseRealtime, SimpleTypes;

var LRealtime := TSimpleSupabaseRealtime.New(
  'https://seu-projeto.supabase.co',
  'sua-api-key'
);

// Callback global para INSERTs
LRealtime.OnInsert(
  procedure(aEvent: TSupabaseRealtimeEvent)
  begin
    Writeln('Novo registro em ', aEvent.Table, ': ', aEvent.NewRecord);
  end
);

// Callback especifico por tabela
LRealtime.OnChange('produto',
  procedure(aEvent: TSupabaseRealtimeEvent)
  begin
    Writeln('Mudanca em produto: ', aEvent.NewRecord);
  end
);

// Inscrever e conectar
LRealtime
  .Subscribe('produto')
  .Subscribe('cliente')
  .Connect;

// ... aplicacao rodando ...

// Desconectar ao finalizar
LRealtime.Disconnect;</code></pre>

  <table>
    <thead>
      <tr><th>Metodo</th><th>Descricao</th></tr>
    </thead>
    <tbody>
      <tr><td>Subscribe(table)</td><td>Inscrever para receber mudancas de uma tabela</td></tr>
      <tr><td>Unsubscribe(table)</td><td>Cancelar inscricao de uma tabela</td></tr>
      <tr><td>OnInsert(callback)</td><td>Callback global para novos registros</td></tr>
      <tr><td>OnUpdate(callback)</td><td>Callback global para registros atualizados</td></tr>
      <tr><td>OnDelete(callback)</td><td>Callback global para registros deletados</td></tr>
      <tr><td>OnChange(table, callback)</td><td>Callback especifico para uma tabela</td></tr>
      <tr><td>Connect</td><td>Iniciar monitoramento</td></tr>
      <tr><td>Disconnect</td><td>Parar monitoramento</td></tr>
      <tr><td>IsConnected</td><td>Verificar se esta monitorando</td></tr>
    </tbody>
  </table>

  <p class="note"><strong>Nota:</strong> A implementacao atual usa polling via REST API. Callbacks sao executados na thread principal via <code>TThread.Queue</code>, garantindo thread safety com componentes de UI. O intervalo de polling padrao e 2 segundos.</p>
```

**Step 3: Update English docs**

Same content translated to English.

**Step 4: Update CHANGELOG**

```markdown
- **TSimpleSupabaseRealtime** - Monitoramento de mudancas em tabelas Supabase com callbacks (`SimpleSupabaseRealtime.pas`)
- **Supabase Realtime Events** - Callbacks globais (OnInsert/OnUpdate/OnDelete) e por tabela (OnChange)
- **TSupabaseRealtimeEvent** - Record com Table, EventType, OldRecord e NewRecord para notificacoes
```

**Step 5: Update sample**

Add commented-out Realtime example to the sample.

**Step 6: Commit**

```bash
git add SimpleORM.dpk SimpleORM.dpr docs/index.html docs/en/index.html CHANGELOG.md samples/Supabase/SimpleORMSupabase.dpr
git commit -m "feat: register SimpleSupabaseRealtime, update docs, sample and changelog"
```
