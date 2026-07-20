unit IB.MCP.AuditLogger;

interface

uses
  Dext.Options,
  IB.MCP.Settings;

type
  /// <summary>
  /// Writes audit events and tool calls.
  /// </summary>
  TIBMCPAuditLogger = class
  private
    FSettings: TIBMCPSettings;
    FOwnsSettings: Boolean;

    class function RedactCredentials(const AText: string): string; static;
    procedure AppendLine(const ALine: string);
  public
    constructor Create; overload;

    destructor Destroy; override;

    /// <summary>
    /// Logs a tool call with credentials redacted.
    /// </summary>
    /// <param name="AToolName">Tool name.</param>
    /// <param name="AParameters">JSON parameters.</param>
    /// <param name="AExecutionMs">Execution time in milliseconds.</param>
    /// <param name="AOutcome">Execution outcome.</param>
    procedure WriteToolCall(
      const AToolName: string;
      const AParameters: string;
      AExecutionMs: Int64;
      const AOutcome: string
    );

    /// <summary>
    /// Logs an internal event.
    /// </summary>
    /// <param name="AEventName">Event name.</param>
    /// <param name="APayload">Event payload.</param>
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

  { TIBMCPAuditLogger }

constructor TIBMCPAuditLogger.Create;
begin
  inherited Create;
  FSettings := TIBMCPSettings.Create;
  FOwnsSettings := True;
end;

destructor TIBMCPAuditLogger.Destroy;
begin
  if FOwnsSettings then
    FSettings.Free;
  inherited Destroy;
end;

procedure TIBMCPAuditLogger.AppendLine(const ALine: string);
var
  FileName: string;
begin
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

class function TIBMCPAuditLogger.RedactCredentials(const AText: string): string;
var
  ResultText: string;
  Key: string;
begin
  ResultText := AText;
  for Key in ['password', 'pwd', 'user_name', 'username', 'user', 'api_key', 'token'] do
    ResultText := TRegEx.Replace(ResultText, Format('("%s"\s*:\s*)"[^"]*"', [Key]), '$1"***"', [roIgnoreCase]);
  Result := ResultText;
end;

procedure TIBMCPAuditLogger.WriteEvent(const AEventName, APayload: string);
begin
  WriteToolCall(AEventName, APayload, 0, 'event');
end;

procedure TIBMCPAuditLogger.WriteToolCall(const AToolName, AParameters: string; AExecutionMs: Int64; const AOutcome: string);
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
