unit IB.Tools.Management;

interface

uses
  System.JSON,
  Dext.AI.MCP.Attributes,
  Dext.AI.MCP.Protocol,
  Dext.AI.MCP.Tools,
  Dext.AI.MCP.Types,
  IB.AuditLogger,
  IB.MCP.Settings;

type
  /// <summary>
  /// MCP tools for InterBase maintenance tasks.
  /// </summary>
  TIBManagementTools = class(TMCPToolProvider)
  private
    FSettings: TIBMCPSettings;
    FAudit: TAuditLogger;
    FOwnsAudit: Boolean;
    class var FNextTaskId: Integer;
    function Accepted(const AOperation: string): TMCPToolResult;
  public
    constructor Create; overload;

    destructor Destroy; override;

    /// <summary>
    /// Queues a backup task.
    /// </summary>
    [MCPTool('backup_database', 'Start an InterBase backup task')]
    [MCPParam('backup_file', 'Backup file path')]
    [MCPParam('verbose', 'Enable verbose output', ptBoolean, False)]
    function BackupDatabase(const Args: TJSONObject): TMCPToolResult; virtual;

    /// <summary>
    /// Queues a restore task.
    /// </summary>
    [MCPTool('restore_database', 'Start an InterBase restore task')]
    [MCPParam('backup_file', 'Backup file path')]
    [MCPParam('target_database', 'Target database path')]
    [MCPParam('page_size', 'Optional page size', ptInteger, False)]
    function RestoreDatabase(const Args: TJSONObject): TMCPToolResult; virtual;

    /// <summary>
    /// Queues a validation task.
    /// </summary>
    [MCPTool('validate_database', 'Start an InterBase validation task')]
    function ValidateDatabase(const Args: TJSONObject): TMCPToolResult; virtual;

    /// <summary>
    /// Queues a sweep task.
    /// </summary>
    [MCPTool('sweep_database', 'Start an InterBase sweep task')]
    function SweepDatabase(const Args: TJSONObject): TMCPToolResult; virtual;
  end;

implementation

uses
  System.SyncObjs,
  System.SysUtils,
  Dext.Threading.Async,
  FireDAC.Comp.Client,
  FireDAC.Phys.IBBase,
  FireDAC.Phys.IBWrapper,
  IB.DatasetHelper;

constructor TIBManagementTools.Create;
begin
  inherited Create;
  FSettings := TIBMCPSettings.Create;
  FAudit := TAuditLogger.Create;
  FOwnsAudit := True;
end;

destructor TIBManagementTools.Destroy;
begin
  if FOwnsAudit then
    FAudit.Free;
  FSettings.Free;
  inherited Destroy;
end;

function TIBManagementTools.Accepted(const AOperation: string): TMCPToolResult;
var
  Json: TJSONObject;
begin
  Json := TJSONObject.Create;
  try
    Json.AddPair('task_id', Format('%s-%d', [AOperation, TInterlocked.Increment(FNextTaskId)]));
    Json.AddPair('operation', AOperation);
    Json.AddPair('status', 'accepted');
    Json.AddPair('progress', 'Dext Hubs/SSE progress publishing is reserved for the transport progress phase.');
    Result := TMCPToolResult.Text(Json.ToJSON);
  finally
    Json.Free;
  end;
end;

function TIBManagementTools.BackupDatabase(const Args: TJSONObject): TMCPToolResult;
begin
  TAsyncTask.Run(procedure begin FAudit.WriteToolCall('backup_database', Args.ToJSON, 0, 'queued'); end).Start;
  Result := Accepted('backup_database');
end;

function TIBManagementTools.RestoreDatabase(const Args: TJSONObject): TMCPToolResult;
begin
  TAsyncTask.Run(procedure begin FAudit.WriteToolCall('restore_database', Args.ToJSON, 0, 'queued'); end).Start;
  Result := Accepted('restore_database');
end;

function TIBManagementTools.ValidateDatabase(const Args: TJSONObject): TMCPToolResult;
begin
  TAsyncTask.Run(procedure begin FAudit.WriteToolCall('validate_database', Args.ToJSON, 0, 'queued'); end).Start;
  Result := Accepted('validate_database');
end;

function TIBManagementTools.SweepDatabase(const Args: TJSONObject): TMCPToolResult;
begin
  TAsyncTask.Run(procedure begin FAudit.WriteToolCall('sweep_database', Args.ToJSON, 0, 'queued'); end).Start;
  Result := Accepted('sweep_database');
end;

end.
