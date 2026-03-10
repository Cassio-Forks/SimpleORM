unit TestSimpleSupabaseRealtime;

interface

uses
  SimpleInterface,
  SimpleTypes,
  SimpleSupabaseRealtime,
  TestFramework;

type
  TTestSupabaseRealtimeContract = class(TTestCase)
  private
    function CreateRealtime: iSimpleSupabaseRealtime;
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

const
  FAKE_URL = 'http://localhost:99999';
  FAKE_KEY = 'fake-api-key';
  HIGH_POLL_INTERVAL = 5000;

{ TTestSupabaseRealtimeContract }

function TTestSupabaseRealtimeContract.CreateRealtime: iSimpleSupabaseRealtime;
begin
  Result := TSimpleSupabaseRealtime.New(FAKE_URL, FAKE_KEY, HIGH_POLL_INTERVAL);
end;

procedure TTestSupabaseRealtimeContract.TestNew_ReturnsInterface;
var
  LRealtime: iSimpleSupabaseRealtime;
begin
  LRealtime := CreateRealtime;
  CheckNotNull(LRealtime, 'New should return a non-nil interface');
end;

procedure TTestSupabaseRealtimeContract.TestIsConnected_InitiallyFalse;
var
  LRealtime: iSimpleSupabaseRealtime;
begin
  LRealtime := CreateRealtime;
  CheckFalse(LRealtime.IsConnected, 'IsConnected should be False initially');
end;

procedure TTestSupabaseRealtimeContract.TestSubscribe_ReturnsSelf;
var
  LRealtime: iSimpleSupabaseRealtime;
  LResult: iSimpleSupabaseRealtime;
begin
  LRealtime := CreateRealtime;
  LResult := LRealtime.Subscribe('test_table');
  CheckTrue(LResult = LRealtime, 'Subscribe should return Self');
end;

procedure TTestSupabaseRealtimeContract.TestUnsubscribe_ReturnsSelf;
var
  LRealtime: iSimpleSupabaseRealtime;
  LResult: iSimpleSupabaseRealtime;
begin
  LRealtime := CreateRealtime;
  LResult := LRealtime.Unsubscribe('nonexistent_table');
  CheckTrue(LResult = LRealtime, 'Unsubscribe should return Self');
end;

procedure TTestSupabaseRealtimeContract.TestOnInsert_ReturnsSelf;
var
  LRealtime: iSimpleSupabaseRealtime;
  LResult: iSimpleSupabaseRealtime;
begin
  LRealtime := CreateRealtime;
  LResult := LRealtime.OnInsert(
    procedure(aEvent: TSupabaseRealtimeEvent)
    begin
    end);
  CheckTrue(LResult = LRealtime, 'OnInsert should return Self');
end;

procedure TTestSupabaseRealtimeContract.TestOnUpdate_ReturnsSelf;
var
  LRealtime: iSimpleSupabaseRealtime;
  LResult: iSimpleSupabaseRealtime;
begin
  LRealtime := CreateRealtime;
  LResult := LRealtime.OnUpdate(
    procedure(aEvent: TSupabaseRealtimeEvent)
    begin
    end);
  CheckTrue(LResult = LRealtime, 'OnUpdate should return Self');
end;

procedure TTestSupabaseRealtimeContract.TestOnDelete_ReturnsSelf;
var
  LRealtime: iSimpleSupabaseRealtime;
  LResult: iSimpleSupabaseRealtime;
begin
  LRealtime := CreateRealtime;
  LResult := LRealtime.OnDelete(
    procedure(aEvent: TSupabaseRealtimeEvent)
    begin
    end);
  CheckTrue(LResult = LRealtime, 'OnDelete should return Self');
end;

procedure TTestSupabaseRealtimeContract.TestOnChange_ReturnsSelf;
var
  LRealtime: iSimpleSupabaseRealtime;
  LResult: iSimpleSupabaseRealtime;
begin
  LRealtime := CreateRealtime;
  LResult := LRealtime.OnChange('test_table',
    procedure(aEvent: TSupabaseRealtimeEvent)
    begin
    end);
  CheckTrue(LResult = LRealtime, 'OnChange should return Self');
end;

procedure TTestSupabaseRealtimeContract.TestConnect_SetsConnected;
var
  LRealtime: iSimpleSupabaseRealtime;
begin
  LRealtime := CreateRealtime;
  LRealtime.Subscribe('test_table');
  LRealtime.Connect;
  try
    CheckTrue(LRealtime.IsConnected, 'IsConnected should be True after Connect');
  finally
    LRealtime.Disconnect;
  end;
end;

procedure TTestSupabaseRealtimeContract.TestDisconnect_ClearsConnected;
var
  LRealtime: iSimpleSupabaseRealtime;
begin
  LRealtime := CreateRealtime;
  LRealtime.Subscribe('test_table');
  LRealtime.Connect;
  try
    LRealtime.Disconnect;
    CheckFalse(LRealtime.IsConnected, 'IsConnected should be False after Disconnect');
  except
    LRealtime.Disconnect;
    raise;
  end;
end;

procedure TTestSupabaseRealtimeContract.TestDisconnect_WhenNotConnected_DoesNotRaise;
var
  LRealtime: iSimpleSupabaseRealtime;
begin
  LRealtime := CreateRealtime;
  try
    LRealtime.Disconnect;
  except
    Fail('Disconnect when not connected should not raise an exception');
  end;
end;

procedure TTestSupabaseRealtimeContract.TestSubscribeAndUnsubscribe_DoesNotRaise;
var
  LRealtime: iSimpleSupabaseRealtime;
begin
  LRealtime := CreateRealtime;
  try
    LRealtime.Subscribe('table_a');
    LRealtime.Subscribe('table_b');
    LRealtime.Subscribe('table_c');
    LRealtime.Unsubscribe('table_b');
    LRealtime.Unsubscribe('table_a');
    LRealtime.Unsubscribe('table_c');
    LRealtime.Unsubscribe('nonexistent_table');
  except
    Fail('Subscribe and Unsubscribe operations should not raise exceptions');
  end;
end;

initialization
  RegisterTest('SupabaseRealtime', TTestSupabaseRealtimeContract.Suite);

end.
