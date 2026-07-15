unit IB.AuditLogger;

interface

uses
  Dext.Options,
  IB.MCP.Settings;

type
  /// <summary>
  /// Provides thread-safe, asynchronous logging for MCP tool calls and internal events.
  /// </summary>
  TAuditLogger = class
  private
    FSettings: TIBSettings;
    FOwnsSettings: Boolean;

    class function RedactCredentials(const AText: string): string; static;
    procedure AppendLine(const ALine: string);
  public
    /// <summary>
    /// Initializes a new instance of the audit logger.
    /// </summary>
    constructor Create; overload;
    
    /// <summary>
    /// Destroys the audit logger and frees owned resources.
    /// </summary>
    destructor Destroy; override;

    /// <summary>
    /// Logs a tool execution call, automatically redacting sensitive credentials.
    /// </summary>
    /// <param name="AToolName">The name of the MCP tool executed.</param>
    /// <param name="AParameters">The JSON parameters passed to the tool.</param>
    /// <param name="AExecutionMs">The execution time in milliseconds.</param>
    /// <param name="AOutcome">The outcome of the execution (e.g., success, error).</param>
    procedure WriteToolCall(
        const AToolName: string;
        const AParameters: string;
        AExecutionMs: Int64;
        const AOutcome: string
    );

    /// <summary>
    /// Logs an internal system event.
    /// </summary>
    /// <param name="AEventName">The name of the event.</param>
    /// <param name="APayload">The payload or details associated with the event.</param>
    procedure WriteEvent(const AEventName, APayload: string);
  end;

implementation

uses
  System.DateUtils,
  System.IOUtils,
  System.JSON,
  System.RegularExpressions,
  System.SysUtils,
  Dext.Threading.Async;

{ TAuditLogger }

constructor TAuditLogger.Create;
begin
  inherited Create;
  FSettings := TIBSettings.Create;
  FOwnsSettings := True;
end;

destructor TAuditLogger.Destroy;
begin
  if FOwnsSettings then
    FSettings.Free;
  inherited Destroy;
end;

procedure TAuditLogger.AppendLine(const ALine: string);
var
  FileName: string;
begin
  if FSettings.LogToConsole then
    Writeln(ALine);

  FileName := ChangeFileExt(FSettings.AuditPath, '.' + FormatDateTime('yyyymmdd', Today) + '.jsonl');
  TAsyncTask
      .Run(
          procedure
          var
            DirectoryName: string;
          begin
            DirectoryName := ExtractFilePath(TPath.GetFullPath(FileName));
            if DirectoryName <> '' then
              TDirectory.CreateDirectory(DirectoryName);
            TFile.AppendAllText(FileName, ALine + sLineBreak, TEncoding.UTF8);
          end)
      .Start;
end;

class function TAuditLogger.RedactCredentials(const AText: string): string;
var
  ResultText: string;
  Key: string;
begin
  ResultText := AText;
  for Key in ['password', 'pwd', 'user_name', 'username', 'user', 'api_key', 'token'] do
    ResultText := TRegEx.Replace(ResultText, Format('("%s"\s*:\s*)"[^"]*"', [Key]), '$1"***"', [roIgnoreCase]);
  Result := ResultText;
end;

procedure TAuditLogger.WriteEvent(const AEventName, APayload: string);
begin
  WriteToolCall(AEventName, APayload, 0, 'event');
end;

procedure TAuditLogger.WriteToolCall(const AToolName, AParameters: string; AExecutionMs: Int64; const AOutcome: string);
var
  Json: TJSONObject;
begin
  Json := TJSONObject.Create;
  try
    Json.AddPair('timestamp', DateToISO8601(TTimeZone.Local.ToUniversalTime(Now), True));
    Json.AddPair('tool', AToolName);
    Json.AddPair('parameters', RedactCredentials(AParameters));
    Json.AddPair('execution_ms', TJSONNumber.Create(AExecutionMs));
    Json.AddPair('outcome', AOutcome);
    AppendLine(Json.ToJSON);
  finally
    Json.Free;
  end;
end;

end.
