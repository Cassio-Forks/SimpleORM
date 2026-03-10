unit SimpleAIClient;

interface

uses
  SimpleInterface,
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Net.HttpClient,
  System.Net.URLClient;

type
  ESimpleAIClient = class(Exception);

  TSimpleAIClient = class(TInterfacedObject, iSimpleAIClient)
  private
    FProvider: String;
    FApiKey: String;
    FModel: String;
    FMaxTokens: Integer;
    FTemperature: Double;
    FTimeout: Integer;
    function CompleteClaude(const aPrompt: String): String;
    function CompleteOpenAI(const aPrompt: String): String;
  public
    constructor Create(const aProvider, aApiKey: String);
    destructor Destroy; override;
    class function New(const aProvider, aApiKey: String): iSimpleAIClient;
    function Complete(const aPrompt: String): String;
    function Model(const aValue: String): iSimpleAIClient;
    function MaxTokens(aValue: Integer): iSimpleAIClient;
    function Temperature(aValue: Double): iSimpleAIClient;
  end;

implementation

{ TSimpleAIClient }

constructor TSimpleAIClient.Create(const aProvider, aApiKey: String);
begin
  FProvider := LowerCase(aProvider);
  FApiKey := aApiKey;
  FMaxTokens := 1024;
  FTemperature := 0.7;
  FTimeout := 30000;

  if FProvider = 'claude' then
    FModel := 'claude-sonnet-4-20250514'
  else if FProvider = 'openai' then
    FModel := 'gpt-4o-mini'
  else
    raise ESimpleAIClient.CreateFmt('Unsupported AI provider: %s. Use "claude" or "openai".', [aProvider]);
end;

destructor TSimpleAIClient.Destroy;
begin
  inherited;
end;

class function TSimpleAIClient.New(const aProvider, aApiKey: String): iSimpleAIClient;
begin
  Result := Self.Create(aProvider, aApiKey);
end;

function TSimpleAIClient.Complete(const aPrompt: String): String;
begin
  if FProvider = 'claude' then
    Result := CompleteClaude(aPrompt)
  else if FProvider = 'openai' then
    Result := CompleteOpenAI(aPrompt)
  else
    raise ESimpleAIClient.CreateFmt('Unsupported AI provider: %s', [FProvider]);
end;

function TSimpleAIClient.Model(const aValue: String): iSimpleAIClient;
begin
  Result := Self;
  FModel := aValue;
end;

function TSimpleAIClient.MaxTokens(aValue: Integer): iSimpleAIClient;
begin
  Result := Self;
  FMaxTokens := aValue;
end;

function TSimpleAIClient.Temperature(aValue: Double): iSimpleAIClient;
begin
  Result := Self;
  FTemperature := aValue;
end;

function TSimpleAIClient.CompleteClaude(const aPrompt: String): String;
var
  LHttpClient: THTTPClient;
  LRequestBody: TStringStream;
  LResponse: IHTTPResponse;
  LRequestJSON: TJSONObject;
  LMessagesArray: TJSONArray;
  LMessageObj: TJSONObject;
  LResponseJSON: TJSONValue;
  LContentArray: TJSONArray;
  LContentObj: TJSONObject;
begin
  LHttpClient := nil;
  LRequestBody := nil;
  LRequestJSON := nil;
  LResponseJSON := nil;
  try
    LHttpClient := THTTPClient.Create;
    LHttpClient.ConnectionTimeout := FTimeout;
    LHttpClient.ResponseTimeout := FTimeout;

    LMessageObj := TJSONObject.Create;
    LMessageObj.AddPair('role', 'user');
    LMessageObj.AddPair('content', aPrompt);

    LMessagesArray := TJSONArray.Create;
    LMessagesArray.AddElement(LMessageObj);

    LRequestJSON := TJSONObject.Create;
    LRequestJSON.AddPair('model', FModel);
    LRequestJSON.AddPair('max_tokens', TJSONNumber.Create(FMaxTokens));
    LRequestJSON.AddPair('temperature', TJSONNumber.Create(FTemperature));
    LRequestJSON.AddPair('messages', LMessagesArray);

    LRequestBody := TStringStream.Create(LRequestJSON.ToJSON, TEncoding.UTF8);

    LHttpClient.CustomHeaders['x-api-key'] := FApiKey;
    LHttpClient.CustomHeaders['anthropic-version'] := '2023-06-01';
    LHttpClient.ContentType := 'application/json';

    LResponse := LHttpClient.Post(
      'https://api.anthropic.com/v1/messages',
      LRequestBody
    );

    if LResponse.StatusCode >= 400 then
      raise ESimpleAIClient.CreateFmt(
        'Claude API error (HTTP %d): %s',
        [LResponse.StatusCode, LResponse.ContentAsString]
      );

    LResponseJSON := TJSONObject.ParseJSONValue(LResponse.ContentAsString);

    if LResponseJSON = nil then
      raise ESimpleAIClient.Create('Claude API returned invalid JSON response');

    LContentArray := (LResponseJSON as TJSONObject).GetValue<TJSONArray>('content');
    if (LContentArray = nil) or (LContentArray.Count = 0) then
      raise ESimpleAIClient.Create('Claude API returned empty content');

    LContentObj := LContentArray.Items[0] as TJSONObject;
    Result := LContentObj.GetValue<String>('text');
  finally
    FreeAndNil(LResponseJSON);
    FreeAndNil(LRequestJSON);
    FreeAndNil(LRequestBody);
    FreeAndNil(LHttpClient);
  end;
end;

function TSimpleAIClient.CompleteOpenAI(const aPrompt: String): String;
var
  LHttpClient: THTTPClient;
  LRequestBody: TStringStream;
  LResponse: IHTTPResponse;
  LRequestJSON: TJSONObject;
  LMessagesArray: TJSONArray;
  LMessageObj: TJSONObject;
  LResponseJSON: TJSONValue;
  LChoicesArray: TJSONArray;
  LChoiceObj: TJSONObject;
  LMessageResponse: TJSONObject;
begin
  LHttpClient := nil;
  LRequestBody := nil;
  LRequestJSON := nil;
  LResponseJSON := nil;
  try
    LHttpClient := THTTPClient.Create;
    LHttpClient.ConnectionTimeout := FTimeout;
    LHttpClient.ResponseTimeout := FTimeout;

    LMessageObj := TJSONObject.Create;
    LMessageObj.AddPair('role', 'user');
    LMessageObj.AddPair('content', aPrompt);

    LMessagesArray := TJSONArray.Create;
    LMessagesArray.AddElement(LMessageObj);

    LRequestJSON := TJSONObject.Create;
    LRequestJSON.AddPair('model', FModel);
    LRequestJSON.AddPair('max_tokens', TJSONNumber.Create(FMaxTokens));
    LRequestJSON.AddPair('temperature', TJSONNumber.Create(FTemperature));
    LRequestJSON.AddPair('messages', LMessagesArray);

    LRequestBody := TStringStream.Create(LRequestJSON.ToJSON, TEncoding.UTF8);

    LHttpClient.CustomHeaders['Authorization'] := 'Bearer ' + FApiKey;
    LHttpClient.ContentType := 'application/json';

    LResponse := LHttpClient.Post(
      'https://api.openai.com/v1/chat/completions',
      LRequestBody
    );

    if LResponse.StatusCode >= 400 then
      raise ESimpleAIClient.CreateFmt(
        'OpenAI API error (HTTP %d): %s',
        [LResponse.StatusCode, LResponse.ContentAsString]
      );

    LResponseJSON := TJSONObject.ParseJSONValue(LResponse.ContentAsString);

    if LResponseJSON = nil then
      raise ESimpleAIClient.Create('OpenAI API returned invalid JSON response');

    LChoicesArray := (LResponseJSON as TJSONObject).GetValue<TJSONArray>('choices');
    if (LChoicesArray = nil) or (LChoicesArray.Count = 0) then
      raise ESimpleAIClient.Create('OpenAI API returned empty choices');

    LChoiceObj := LChoicesArray.Items[0] as TJSONObject;
    LMessageResponse := LChoiceObj.GetValue<TJSONObject>('message');
    Result := LMessageResponse.GetValue<String>('content');
  finally
    FreeAndNil(LResponseJSON);
    FreeAndNil(LRequestJSON);
    FreeAndNil(LRequestBody);
    FreeAndNil(LHttpClient);
  end;
end;

end.
