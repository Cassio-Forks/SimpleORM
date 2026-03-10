unit SimpleAIAttributes;

interface

uses
  System.SysUtils;

type
  /// AI-generated content: LLM generates value based on a prompt template.
  /// Template can reference other property values with {PropertyName}.
  AIGenerated = class(TCustomAttribute)
  private
    FPromptTemplate: String;
  public
    constructor Create(const aPromptTemplate: String);
    property PromptTemplate: String read FPromptTemplate;
  end;

  /// AI summarization: LLM creates a summary of the source property value.
  AISummarize = class(TCustomAttribute)
  private
    FSourceProperty: String;
    FMaxLength: Integer;
  public
    constructor Create(const aSourceProperty: String; aMaxLength: Integer = 0);
    property SourceProperty: String read FSourceProperty;
    property MaxLength: Integer read FMaxLength;
  end;

  /// AI translation: LLM translates the source property to target language.
  AITranslate = class(TCustomAttribute)
  private
    FSourceProperty: String;
    FTargetLanguage: String;
  public
    constructor Create(const aSourceProperty: String; const aTargetLanguage: String);
    property SourceProperty: String read FSourceProperty;
    property TargetLanguage: String read FTargetLanguage;
  end;

  /// AI classification: LLM classifies the source property into one of the given categories.
  AIClassify = class(TCustomAttribute)
  private
    FSourceProperty: String;
    FCategories: String;
  public
    constructor Create(const aSourceProperty: String; const aCategories: String);
    property SourceProperty: String read FSourceProperty;
    property Categories: String read FCategories;
  end;

  /// AI validation: LLM validates a property value against a rule.
  /// Raises exception if validation fails.
  AIValidate = class(TCustomAttribute)
  private
    FRule: String;
    FErrorMessage: String;
  public
    constructor Create(const aRule: String; const aErrorMessage: String = '');
    property Rule: String read FRule;
    property ErrorMessage: String read FErrorMessage;
  end;

implementation

{ AIGenerated }

constructor AIGenerated.Create(const aPromptTemplate: String);
begin
  FPromptTemplate := aPromptTemplate;
end;

{ AISummarize }

constructor AISummarize.Create(const aSourceProperty: String; aMaxLength: Integer);
begin
  FSourceProperty := aSourceProperty;
  FMaxLength := aMaxLength;
end;

{ AITranslate }

constructor AITranslate.Create(const aSourceProperty: String; const aTargetLanguage: String);
begin
  FSourceProperty := aSourceProperty;
  FTargetLanguage := aTargetLanguage;
end;

{ AIClassify }

constructor AIClassify.Create(const aSourceProperty: String; const aCategories: String);
begin
  FSourceProperty := aSourceProperty;
  FCategories := aCategories;
end;

{ AIValidate }

constructor AIValidate.Create(const aRule: String; const aErrorMessage: String);
begin
  FRule := aRule;
  FErrorMessage := aErrorMessage;
end;

end.
