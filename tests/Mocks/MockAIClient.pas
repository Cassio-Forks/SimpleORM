unit MockAIClient;

interface

uses
  SimpleInterface,
  System.SysUtils;

type
  TSimpleAIMockClient = class(TInterfacedObject, iSimpleAIClient)
  private
    FFixedResponse: String;
    FLastPrompt: String;
    FModel: String;
    FMaxTokens: Integer;
    FTemperature: Double;
  public
    constructor Create(const aFixedResponse: String);
    destructor Destroy; override;
    class function New(const aFixedResponse: String): iSimpleAIClient;
    function Complete(const aPrompt: String): String;
    function Model(const aValue: String): iSimpleAIClient;
    function MaxTokens(aValue: Integer): iSimpleAIClient;
    function Temperature(aValue: Double): iSimpleAIClient;
    property LastPrompt: String read FLastPrompt;
  end;

implementation

constructor TSimpleAIMockClient.Create(const aFixedResponse: String);
begin
  FFixedResponse := aFixedResponse;
  FModel := 'mock-model';
  FMaxTokens := 1024;
  FTemperature := 0.7;
end;

destructor TSimpleAIMockClient.Destroy;
begin
  inherited;
end;

class function TSimpleAIMockClient.New(const aFixedResponse: String): iSimpleAIClient;
begin
  Result := Self.Create(aFixedResponse);
end;

function TSimpleAIMockClient.Complete(const aPrompt: String): String;
begin
  FLastPrompt := aPrompt;
  Result := FFixedResponse;
end;

function TSimpleAIMockClient.Model(const aValue: String): iSimpleAIClient;
begin
  Result := Self;
  FModel := aValue;
end;

function TSimpleAIMockClient.MaxTokens(aValue: Integer): iSimpleAIClient;
begin
  Result := Self;
  FMaxTokens := aValue;
end;

function TSimpleAIMockClient.Temperature(aValue: Double): iSimpleAIClient;
begin
  Result := Self;
  FTemperature := aValue;
end;

end.
