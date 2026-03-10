# Supabase Auth (Fase 2) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create `TSimpleSupabaseAuth` implementing `iSimpleSupabaseAuth` for Supabase authentication (SignIn, SignUp, SignOut, RefreshToken) with automatic JWT management.

**Architecture:** A standalone auth class that calls Supabase Auth API endpoints (`/auth/v1/`). The auth instance is passed to `TSimpleQuerySupabase` constructor, which automatically uses the JWT token for requests. Token auto-refresh is handled before each request by checking expiry.

**Tech Stack:** Delphi Object Pascal, `System.Net.HttpClient`, `System.JSON`, DUnit

---

### Task 1: Add iSimpleSupabaseAuth interface to SimpleInterface.pas

**Files:**
- Modify: `src/SimpleInterface.pas`

**Step 1: Add interface declaration**

After the `iSimpleQuery` interface (after line 168), add:

```pascal
  iSimpleSupabaseAuth = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function SignIn(aEmail, aPassword: String): iSimpleSupabaseAuth;
    function SignUp(aEmail, aPassword: String): iSimpleSupabaseAuth;
    function SignOut: iSimpleSupabaseAuth;
    function RefreshToken: iSimpleSupabaseAuth;
    function Token: String;
    function User: String;
    function IsAuthenticated: Boolean;
    function ExpiresAt: TDateTime;
  end;
```

Note: `User` returns String (JSON string) instead of TJSONObject to avoid ownership issues. `ExpiresAt` added for checking token expiry.

**Step 2: Commit**

```bash
git add src/SimpleInterface.pas
git commit -m "feat: add iSimpleSupabaseAuth interface to SimpleInterface.pas"
```

---

### Task 2: Create TSimpleSupabaseAuth implementation

**Files:**
- Create: `src/SimpleSupabaseAuth.pas`

**Step 1: Create the unit**

```pascal
unit SimpleSupabaseAuth;

interface

uses
  SimpleInterface, System.SysUtils, System.Classes, System.JSON,
  System.Net.HttpClient, System.Net.URLClient, System.DateUtils;

type
  TSimpleSupabaseAuth = class(TInterfacedObject, iSimpleSupabaseAuth)
  private
    FBaseURL: string;
    FAPIKey: string;
    FAccessToken: string;
    FRefreshTokenValue: string;
    FUserJSON: string;
    FExpiresAt: TDateTime;

    function DoAuthRequest(const aEndpoint, aBody: string): TJSONObject;
    procedure ParseAuthResponse(aResponse: TJSONObject);
  public
    constructor Create(aBaseURL, aAPIKey: string);
    destructor Destroy; override;
    class function New(aBaseURL, aAPIKey: string): iSimpleSupabaseAuth;

    { iSimpleSupabaseAuth }
    function SignIn(aEmail, aPassword: String): iSimpleSupabaseAuth;
    function SignUp(aEmail, aPassword: String): iSimpleSupabaseAuth;
    function SignOut: iSimpleSupabaseAuth;
    function RefreshToken: iSimpleSupabaseAuth;
    function Token: String;
    function User: String;
    function IsAuthenticated: Boolean;
    function ExpiresAt: TDateTime;
  end;

implementation

constructor TSimpleSupabaseAuth.Create(aBaseURL, aAPIKey: string);
begin
  inherited Create;
  FBaseURL := aBaseURL.TrimRight(['/']);
  FAPIKey := aAPIKey;
  FAccessToken := '';
  FRefreshTokenValue := '';
  FUserJSON := '';
  FExpiresAt := 0;
end;

destructor TSimpleSupabaseAuth.Destroy;
begin
  inherited;
end;

class function TSimpleSupabaseAuth.New(aBaseURL, aAPIKey: string): iSimpleSupabaseAuth;
begin
  Result := Self.Create(aBaseURL, aAPIKey);
end;

function TSimpleSupabaseAuth.DoAuthRequest(const aEndpoint, aBody: string): TJSONObject;
var
  LClient: THTTPClient;
  LContent: TStringStream;
  LResponse: IHTTPResponse;
  LResponseStr: string;
  LValue: TJSONValue;
begin
  Result := nil;
  LClient := THTTPClient.Create;
  try
    LClient.ContentType := 'application/json';
    LClient.CustomHeaders['apikey'] := FAPIKey;

    LContent := TStringStream.Create(aBody, TEncoding.UTF8);
    try
      LResponse := LClient.Post(FBaseURL + aEndpoint, LContent);
    finally
      LContent.Free;
    end;

    if not Assigned(LResponse) then
      raise Exception.Create('Supabase Auth: no response received');

    LResponseStr := LResponse.ContentAsString(TEncoding.UTF8);

    if LResponse.StatusCode >= 400 then
      raise Exception.CreateFmt('Supabase Auth HTTP %d: %s',
        [LResponse.StatusCode, LResponseStr]);

    LValue := TJSONObject.ParseJSONValue(LResponseStr);
    if not Assigned(LValue) then
      raise Exception.Create('Supabase Auth: invalid JSON response');

    if not (LValue is TJSONObject) then
    begin
      LValue.Free;
      raise Exception.Create('Supabase Auth: expected JSON object');
    end;

    Result := TJSONObject(LValue);
  finally
    LClient.Free;
  end;
end;

procedure TSimpleSupabaseAuth.ParseAuthResponse(aResponse: TJSONObject);
var
  LExpiresIn: Integer;
  LUserObj: TJSONValue;
begin
  if Assigned(aResponse.Values['access_token']) then
    FAccessToken := aResponse.Values['access_token'].Value;

  if Assigned(aResponse.Values['refresh_token']) then
    FRefreshTokenValue := aResponse.Values['refresh_token'].Value;

  if Assigned(aResponse.Values['expires_in']) then
  begin
    LExpiresIn := (aResponse.Values['expires_in'] as TJSONNumber).AsInt;
    FExpiresAt := IncSecond(Now, LExpiresIn);
  end;

  LUserObj := aResponse.Values['user'];
  if Assigned(LUserObj) then
    FUserJSON := LUserObj.ToString
  else
    FUserJSON := '';
end;

function TSimpleSupabaseAuth.SignIn(aEmail, aPassword: String): iSimpleSupabaseAuth;
var
  LBody: TJSONObject;
  LBodyStr: string;
  LResponse: TJSONObject;
begin
  Result := Self;
  LBody := TJSONObject.Create;
  try
    LBody.AddPair('email', aEmail);
    LBody.AddPair('password', aPassword);
    LBodyStr := LBody.ToString;
  finally
    LBody.Free;
  end;

  LResponse := DoAuthRequest('/auth/v1/token?grant_type=password', LBodyStr);
  try
    ParseAuthResponse(LResponse);
  finally
    LResponse.Free;
  end;
end;

function TSimpleSupabaseAuth.SignUp(aEmail, aPassword: String): iSimpleSupabaseAuth;
var
  LBody: TJSONObject;
  LBodyStr: string;
  LResponse: TJSONObject;
begin
  Result := Self;
  LBody := TJSONObject.Create;
  try
    LBody.AddPair('email', aEmail);
    LBody.AddPair('password', aPassword);
    LBodyStr := LBody.ToString;
  finally
    LBody.Free;
  end;

  LResponse := DoAuthRequest('/auth/v1/signup', LBodyStr);
  try
    ParseAuthResponse(LResponse);
  finally
    LResponse.Free;
  end;
end;

function TSimpleSupabaseAuth.SignOut: iSimpleSupabaseAuth;
var
  LClient: THTTPClient;
  LContent: TStringStream;
  LResponse: IHTTPResponse;
begin
  Result := Self;

  if FAccessToken <> '' then
  begin
    LClient := THTTPClient.Create;
    try
      LClient.ContentType := 'application/json';
      LClient.CustomHeaders['apikey'] := FAPIKey;
      LClient.CustomHeaders['Authorization'] := 'Bearer ' + FAccessToken;

      LContent := TStringStream.Create('', TEncoding.UTF8);
      try
        LResponse := LClient.Post(FBaseURL + '/auth/v1/logout', LContent);
      finally
        LContent.Free;
      end;
    finally
      LClient.Free;
    end;
  end;

  FAccessToken := '';
  FRefreshTokenValue := '';
  FUserJSON := '';
  FExpiresAt := 0;
end;

function TSimpleSupabaseAuth.RefreshToken: iSimpleSupabaseAuth;
var
  LBody: TJSONObject;
  LBodyStr: string;
  LResponse: TJSONObject;
begin
  Result := Self;

  if FRefreshTokenValue = '' then
    raise Exception.Create('Supabase Auth: no refresh token available. Sign in first.');

  LBody := TJSONObject.Create;
  try
    LBody.AddPair('refresh_token', FRefreshTokenValue);
    LBodyStr := LBody.ToString;
  finally
    LBody.Free;
  end;

  LResponse := DoAuthRequest('/auth/v1/token?grant_type=refresh_token', LBodyStr);
  try
    ParseAuthResponse(LResponse);
  finally
    LResponse.Free;
  end;
end;

function TSimpleSupabaseAuth.Token: String;
begin
  { Auto-refresh if token is about to expire (within 30 seconds) }
  if (FAccessToken <> '') and (FRefreshTokenValue <> '') and
     (FExpiresAt > 0) and (Now >= IncSecond(FExpiresAt, -30)) then
  begin
    try
      RefreshToken;
    except
      { If refresh fails, return current token anyway }
    end;
  end;

  Result := FAccessToken;
end;

function TSimpleSupabaseAuth.User: String;
begin
  Result := FUserJSON;
end;

function TSimpleSupabaseAuth.IsAuthenticated: Boolean;
begin
  Result := FAccessToken <> '';
end;

function TSimpleSupabaseAuth.ExpiresAt: TDateTime;
begin
  Result := FExpiresAt;
end;

end.
```

**Step 2: Commit**

```bash
git add src/SimpleSupabaseAuth.pas
git commit -m "feat: create TSimpleSupabaseAuth with SignIn, SignUp, SignOut, RefreshToken"
```

---

### Task 3: Integrate Auth with TSimpleQuerySupabase

**Files:**
- Modify: `src/SimpleQuerySupabase.pas`

**Step 1: Add FAuth field and constructor overload**

Add to private fields:
```pascal
FAuth: iSimpleSupabaseAuth;
```

Add new constructor overload:
```pascal
constructor Create(aBaseURL, aAPIKey: string; aAuth: iSimpleSupabaseAuth); overload;
class function New(aBaseURL, aAPIKey: string; aAuth: iSimpleSupabaseAuth): iSimpleQuery; overload;
```

Implementation:
```pascal
constructor TSimpleQuerySupabase.Create(aBaseURL, aAPIKey: string; aAuth: iSimpleSupabaseAuth);
begin
  Create(aBaseURL, aAPIKey, '');
  FAuth := aAuth;
end;

class function TSimpleQuerySupabase.New(aBaseURL, aAPIKey: string; aAuth: iSimpleSupabaseAuth): iSimpleQuery;
begin
  Result := Self.Create(aBaseURL, aAPIKey, aAuth);
end;
```

**Step 2: Update DoHTTPRequest to use Auth token**

In `DoHTTPRequest`, change the auth token logic:
```pascal
if Assigned(FAuth) and FAuth.IsAuthenticated then
  LAuthToken := FAuth.Token  { Auto-refreshes if needed }
else if FToken <> '' then
  LAuthToken := FToken
else
  LAuthToken := FAPIKey;
```

Add `SimpleSupabaseAuth` to the uses clause.

**Step 3: Commit**

```bash
git add src/SimpleQuerySupabase.pas
git commit -m "feat: integrate iSimpleSupabaseAuth with TSimpleQuerySupabase"
```

---

### Task 4: Create tests for TSimpleSupabaseAuth

**Files:**
- Create: `tests/TestSimpleSupabaseAuth.pas`
- Modify: `tests/SimpleORMTests.dpr`

**Step 1: Create test file**

Test the non-HTTP logic: constructor, initial state, token management. We cannot test actual SignIn/SignUp without a Supabase instance, but we can test:

```pascal
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
  CheckEquals(0, FAuth.ExpiresAt, 'ExpiresAt should be 0 initially');
end;

procedure TTestSupabaseAuthContract.TestSignOut_ClearsState;
begin
  { SignOut on unauthenticated should not raise }
  FAuth.SignOut;
  CheckFalse(FAuth.IsAuthenticated, 'Should remain unauthenticated after SignOut');
  CheckEquals('', FAuth.Token, 'Token should be empty after SignOut');
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
      CheckTrue(Pos('refresh token', E.Message.ToLower) > 0,
        'Error should mention refresh token');
    end;
  end;
  CheckTrue(LRaised, 'RefreshToken without SignIn should raise');
end;

initialization
  RegisterTest('SupabaseAuth', TTestSupabaseAuthContract.Suite);

end.
```

**Step 2: Register in test runner**

Add to `tests/SimpleORMTests.dpr` uses clause:
```pascal
  SimpleSupabaseAuth in '..\src\SimpleSupabaseAuth.pas',
  TestSimpleSupabaseAuth in 'TestSimpleSupabaseAuth.pas';
```

**Step 3: Commit**

```bash
git add tests/TestSimpleSupabaseAuth.pas tests/SimpleORMTests.dpr
git commit -m "test: add unit tests for TSimpleSupabaseAuth"
```

---

### Task 5: Register in packages, update docs, sample, changelog

**Files:**
- Modify: `SimpleORM.dpk` — add `SimpleSupabaseAuth`
- Modify: `SimpleORM.dpr` — add `SimpleSupabaseAuth`
- Modify: `docs/index.html` — add Auth section
- Modify: `docs/en/index.html` — add Auth section
- Modify: `CHANGELOG.md` — add Auth entries
- Modify: `samples/Supabase/SimpleORMSupabase.dpr` — add Auth example (commented out)

**Step 1: Register in packages**

Add `SimpleSupabaseAuth in 'src\SimpleSupabaseAuth.pas'` to both SimpleORM.dpk and SimpleORM.dpr.

**Step 2: Update docs**

Add Auth subsection to the existing Supabase section in both PT and EN docs:

PT:
```html
<h3>Autenticacao</h3>
<pre><code>uses SimpleSupabaseAuth, SimpleQuerySupabase;

var
  LAuth: iSimpleSupabaseAuth;
  LQuery: iSimpleQuery;

// Criar instancia de auth
LAuth := TSimpleSupabaseAuth.New(
  'https://seu-projeto.supabase.co',
  'sua-anon-key'
);

// Fazer login
LAuth.SignIn('usuario@email.com', 'senha123');

// Criar query com auth (JWT automatico)
LQuery := TSimpleQuerySupabase.New(
  'https://seu-projeto.supabase.co',
  'sua-anon-key',
  LAuth
);

// CRUD com Row Level Security ativo
var LDAO := TSimpleDAO&lt;TProduto&gt;.New(LQuery);
LDAO.Find; // GET com Bearer JWT

// Verificar estado
if LAuth.IsAuthenticated then
  Writeln('Logado como: ', LAuth.User);

// Logout
LAuth.SignOut;</code></pre>
```

**Step 3: Update CHANGELOG**

Add under [Unreleased] > Added:
```markdown
- **TSimpleSupabaseAuth** - Autenticacao Supabase com SignIn, SignUp, SignOut e RefreshToken (`SimpleSupabaseAuth.pas`)
- **Supabase Auto-Refresh** - Token JWT renovado automaticamente quando proximo da expiracao
- **Supabase Auth + Query** - Novo construtor `TSimpleQuerySupabase.New(url, key, auth)` para integrar autenticacao com queries
```

**Step 4: Update sample with Auth example**

Add a commented-out section to the sample showing Auth usage.

**Step 5: Commit**

```bash
git add SimpleORM.dpk SimpleORM.dpr docs/index.html docs/en/index.html CHANGELOG.md samples/Supabase/SimpleORMSupabase.dpr
git commit -m "feat: register SimpleSupabaseAuth, update docs and sample"
```
