unit TestSimpleSupabaseAuth;

interface

uses
  TestFramework, System.SysUtils, System.JSON, System.DateUtils,
  SimpleInterface, SimpleSupabaseAuth;

type
  TTestSupabaseAuthContract = class(TTestCase)
  private
    FAuth: iSimpleSupabaseAuth;
  protected
    procedure SetUp; override;
  published
    procedure TestNew_ReturnsInterface;
    procedure TestIsAuthenticated_InitiallyFalse;
    procedure TestToken_InitiallyEmpty;
    procedure TestUser_InitiallyEmpty;
    procedure TestExpiresAt_InitiallyZero;
    procedure TestSignOut_ClearsState;
    procedure TestSignOut_WhenNotAuthenticated_DoesNotRaise;
    procedure TestRefreshToken_WithoutSignIn_RaisesException;
  end;

implementation

procedure TTestSupabaseAuthContract.SetUp;
begin
  inherited;
  FAuth := TSimpleSupabaseAuth.New('https://test.supabase.co', 'test-api-key');
end;

procedure TTestSupabaseAuthContract.TestNew_ReturnsInterface;
begin
  CheckNotNull(FAuth, 'New should return non-nil interface');
end;

procedure TTestSupabaseAuthContract.TestIsAuthenticated_InitiallyFalse;
begin
  CheckFalse(FAuth.IsAuthenticated, 'Should not be authenticated initially');
end;

procedure TTestSupabaseAuthContract.TestToken_InitiallyEmpty;
begin
  CheckEquals('', FAuth.Token, 'Token should be empty initially');
end;

procedure TTestSupabaseAuthContract.TestUser_InitiallyEmpty;
begin
  CheckEquals('', FAuth.User, 'User should be empty initially');
end;

procedure TTestSupabaseAuthContract.TestExpiresAt_InitiallyZero;
begin
  CheckTrue(FAuth.ExpiresAt = 0, 'ExpiresAt should be 0 initially');
end;

procedure TTestSupabaseAuthContract.TestSignOut_ClearsState;
begin
  FAuth.SignOut;
  CheckFalse(FAuth.IsAuthenticated, 'Should remain unauthenticated after SignOut');
  CheckEquals('', FAuth.Token, 'Token should be empty after SignOut');
  CheckEquals('', FAuth.User, 'User should be empty after SignOut');
end;

procedure TTestSupabaseAuthContract.TestSignOut_WhenNotAuthenticated_DoesNotRaise;
begin
  // Should not raise when called without prior SignIn
  FAuth.SignOut;
  CheckFalse(FAuth.IsAuthenticated);
end;

procedure TTestSupabaseAuthContract.TestRefreshToken_WithoutSignIn_RaisesException;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    FAuth.RefreshToken;
  except
    on E: Exception do
    begin
      LRaised := True;
      CheckTrue(Pos('refresh', E.Message.ToLower) > 0,
        'Error message should mention refresh token: ' + E.Message);
    end;
  end;
  CheckTrue(LRaised, 'RefreshToken without SignIn should raise exception');
end;

initialization
  RegisterTest('SupabaseAuth', TTestSupabaseAuthContract.Suite);

end.
