unit IB.MCP.Management;

interface

uses
  System.JSON,
  Dext.AI.MCP.Attributes,
  Dext.AI.MCP.Protocol,
  Dext.AI.MCP.Tools,
  Dext.AI.MCP.Types,
  IB.MCP.AuditLogger,
  IB.MCP.Settings;

type
  /// <summary>
  /// MCP tools for InterBase maintenance tasks.
  /// </summary>
  TIBMCPManagementTools = class(TMCPToolProvider)
  private
    FSettings: TIBMCPSettings;
    FAudit: TIBMCPAuditLogger;
    function BuildResult(const AOperation, AStatus: string; AElapsedMilliseconds: Int64;
    ALogs: TJSONArray; const AErrorMessage: string = ''): TMCPToolResult;
  public
    constructor Create; overload;
    destructor Destroy; override;

    /// <summary>
    /// Runs an InterBase backup.
    /// </summary>
    [MCPTool('backup_database', 'Run an InterBase backup task')]
    [MCPParam('backup_file', 'Backup file path')]
    function BackupDatabase(const Args: TJSONObject): TMCPToolResult; virtual;

    /// <summary>
    /// Runs an InterBase restore.
    /// </summary>
    [MCPTool('restore_database', 'Run an InterBase restore task')]
    [MCPParam('backup_file', 'Backup file path')]
    [MCPParam('target_database', 'Target database path')]
    [MCPParam('page_size', 'Optional page size', ptInteger, False)]
    function RestoreDatabase(const Args: TJSONObject): TMCPToolResult; virtual;

    /// <summary>
    /// Runs an InterBase validation.
    /// </summary>
    [MCPTool('validate_database', 'Run an InterBase validation task')]
    [MCPParam('repair', 'Attempt to repair corruption if found', ptBoolean, False)]
    function ValidateDatabase(const Args: TJSONObject): TMCPToolResult; virtual;

    /// <summary>
    /// Runs an InterBase sweep.
    /// </summary>
    [MCPTool('sweep_database', 'Run an InterBase sweep task')]
    function SweepDatabase(const Args: TJSONObject): TMCPToolResult; virtual;
  end;

implementation

uses
  System.Classes,
  System.Diagnostics,
  System.SysUtils,
  FireDAC.Comp.Client,
  FireDAC.Phys,
  FireDAC.Phys.IBBase,
  FireDAC.Phys.IBWrapper,
  FireDAC.Phys.IB,
  IB.MCP.App,
  IB.MCP.DatasetHelper;

type
  TServiceProgressReceiver = class
  private
    FLogs: TStrings;
  public
    constructor Create(ALogs: TStrings);
    procedure OnProgress(Sender: TFDPhysDriverService; const AMessage: string);
  end;

constructor TServiceProgressReceiver.Create(ALogs: TStrings);
begin
  inherited Create;
  FLogs := ALogs;
end;

procedure TServiceProgressReceiver.OnProgress(Sender: TFDPhysDriverService; const AMessage: string);
begin
  if Assigned(FLogs) then
    FLogs.Add(AMessage);
end;

{ TIBMCPManagementTools }

constructor TIBMCPManagementTools.Create;
begin
  inherited Create;
  FSettings := TIBMCPApp.Current.Settings;
  FAudit := TIBMCPApp.Current.AuditLogger;
end;

destructor TIBMCPManagementTools.Destroy;
begin
  inherited Destroy;
end;

function TIBMCPManagementTools.BuildResult(const AOperation, AStatus: string; AElapsedMilliseconds: Int64;
  ALogs: TJSONArray; const AErrorMessage: string): TMCPToolResult;
var
  LJson: TJSONObject;
begin
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('operation', AOperation);
    LJson.AddPair('status', AStatus);
    LJson.AddPair('elapsed_ms', TJSONNumber.Create(AElapsedMilliseconds));
    if AErrorMessage <> '' then
      LJson.AddPair('error_message', AErrorMessage);
    if Assigned(ALogs) then
      LJson.AddPair('logs', ALogs.Clone as TJSONValue);
    Result := TMCPToolResult.Text(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

function LogsToJSONArray(ALogs: TStrings): TJSONArray;
var
  I: Integer;
begin
  Result := TJSONArray.Create;
  for I := 0 to ALogs.Count - 1 do
    Result.Add(ALogs[I]);
end;

function TIBMCPManagementTools.BackupDatabase(const Args: TJSONObject): TMCPToolResult;
var
  LBackupFile: string;
  LBackup: TFDIBBackup;
  LDriverLink: TFDPhysIBDriverLink;
  LLogs: TStringList;
  LLogsJson: TJSONArray;
  LReceiver: TServiceProgressReceiver;
  LStopwatch: TStopwatch;
begin
  if not(urDba in TIBMCPApp.Current.UserLevel) then
    Exit(TMCPToolResult.Error('Forbidden: DBA access required'));

  LBackupFile := Args.GetValue<string>('backup_file', '');
  if LBackupFile = '' then
    Exit(TMCPToolResult.Error('Parameter backup_file is required.'));

  LLogs := TStringList.Create;
  LReceiver := TServiceProgressReceiver.Create(LLogs);
  LDriverLink := TFDPhysIBDriverLink.Create(nil);
  LBackup := TFDIBBackup.Create(nil);
  LStopwatch := TStopwatch.StartNew;
  try
    try
      LBackup.DriverLink := LDriverLink;
      LBackup.Host := FSettings.Host;
      LBackup.Protocol := ipTCPIP;
      LBackup.UserName := FSettings.UserName;
      LBackup.Password := FSettings.Password;
      LBackup.Database := FSettings.Database;
      LBackup.BackupFiles.Clear;
      LBackup.BackupFiles.Add(LBackupFile);
      LBackup.OnProgress := LReceiver.OnProgress;
      LBackup.Verbose := True;
      LBackup.Backup;

      LStopwatch.Stop;
      LLogs.Add(Format('Task completed successfully in %d ms.', [LStopwatch.ElapsedMilliseconds]));
      FAudit.WriteToolCall('backup_database', Args.ToJSON, LStopwatch.ElapsedMilliseconds, 'success');
      LLogsJson := LogsToJSONArray(LLogs);
      try
        Result := BuildResult('backup_database', 'completed', LStopwatch.ElapsedMilliseconds, LLogsJson);
      finally
        LLogsJson.Free;
      end;
    except
      on E: Exception do
        begin
          LStopwatch.Stop;
          LLogs.Add('Task failed: ' + E.Message);
          FAudit.WriteToolCall('backup_database', Args.ToJSON, LStopwatch.ElapsedMilliseconds, 'error: ' + E.Message);
          LLogsJson := LogsToJSONArray(LLogs);
          try
            Result := BuildResult('backup_database', 'failed', LStopwatch.ElapsedMilliseconds, LLogsJson, E.Message);
          finally
            LLogsJson.Free;
          end;
        end;
    end;
  finally
    LBackup.Free;
    LDriverLink.Free;
    LReceiver.Free;
    LLogs.Free;
  end;
end;

function TIBMCPManagementTools.RestoreDatabase(const Args: TJSONObject): TMCPToolResult;
var
  LBackupFile: string;
  LTargetDatabase: string;
  LPageSize: Integer;
  LRestore: TFDIBRestore;
  LDriverLink: TFDPhysIBDriverLink;
  LLogs: TStringList;
  LLogsJson: TJSONArray;
  LReceiver: TServiceProgressReceiver;
  LStopwatch: TStopwatch;
begin
  if not(urDba in TIBMCPApp.Current.UserLevel) then
    Exit(TMCPToolResult.Error('Forbidden: DBA access required'));

  LBackupFile := Args.GetValue<string>('backup_file', '');
  LTargetDatabase := Args.GetValue<string>('target_database', '');
  if LBackupFile = '' then
    Exit(TMCPToolResult.Error('Parameter backup_file is required.'));
  if LTargetDatabase = '' then
    Exit(TMCPToolResult.Error('Parameter target_database is required.'));
  LPageSize := Args.GetValue<Integer>('page_size', 0);

  LLogs := TStringList.Create;
  LReceiver := TServiceProgressReceiver.Create(LLogs);
  LDriverLink := TFDPhysIBDriverLink.Create(nil);
  LRestore := TFDIBRestore.Create(nil);
  LStopwatch := TStopwatch.StartNew;
  try
    try
      LRestore.DriverLink := LDriverLink;
      LRestore.Host := FSettings.Host;
      LRestore.Protocol := ipTCPIP;
      LRestore.UserName := FSettings.UserName;
      LRestore.Password := FSettings.Password;
      LRestore.Database := LTargetDatabase;
      LRestore.BackupFiles.Clear;
      LRestore.BackupFiles.Add(LBackupFile);
      if LPageSize > 0 then
        LRestore.PageSize := LPageSize;
      LRestore.Options := [roReplace];
      LRestore.OnProgress := LReceiver.OnProgress;
      LRestore.Verbose := True;
      LRestore.Restore;

      LStopwatch.Stop;
      LLogs.Add(Format('Task completed successfully in %d ms.', [LStopwatch.ElapsedMilliseconds]));
      FAudit.WriteToolCall('restore_database', Args.ToJSON, LStopwatch.ElapsedMilliseconds, 'success');
      LLogsJson := LogsToJSONArray(LLogs);
      try
        Result := BuildResult('restore_database', 'completed', LStopwatch.ElapsedMilliseconds, LLogsJson);
      finally
        LLogsJson.Free;
      end;
    except
      on E: Exception do
        begin
          LStopwatch.Stop;
          LLogs.Add('Task failed: ' + E.Message);
          FAudit.WriteToolCall('restore_database', Args.ToJSON, LStopwatch.ElapsedMilliseconds, 'error: ' + E.Message);
          LLogsJson := LogsToJSONArray(LLogs);
          try
            Result := BuildResult('restore_database', 'failed', LStopwatch.ElapsedMilliseconds, LLogsJson, E.Message);
          finally
            LLogsJson.Free;
          end;
        end;
    end;
  finally
    LRestore.Free;
    LDriverLink.Free;
    LReceiver.Free;
    LLogs.Free;
  end;
end;

function TIBMCPManagementTools.ValidateDatabase(const Args: TJSONObject): TMCPToolResult;
var
  LRepair: Boolean;
  LValidate: TFDIBValidate;
  LDriverLink: TFDPhysIBDriverLink;
  LLogs: TStringList;
  LLogsJson: TJSONArray;
  LReceiver: TServiceProgressReceiver;
  LStopwatch: TStopwatch;
begin
  if not(urDba in TIBMCPApp.Current.UserLevel) then
    Exit(TMCPToolResult.Error('Forbidden: DBA access required'));

  LRepair := Args.GetValue<Boolean>('repair', False);

  LLogs := TStringList.Create;
  LReceiver := TServiceProgressReceiver.Create(LLogs);
  LDriverLink := TFDPhysIBDriverLink.Create(nil);
  LValidate := TFDIBValidate.Create(nil);
  LStopwatch := TStopwatch.StartNew;
  try
    try
      LValidate.DriverLink := LDriverLink;
      LValidate.Host := FSettings.Host;
      LValidate.Protocol := ipTCPIP;
      LValidate.UserName := FSettings.UserName;
      LValidate.Password := FSettings.Password;
      LValidate.Database := FSettings.Database;
      LValidate.OnProgress := LReceiver.OnProgress;

      if LRepair then
        begin
          LLogs.Add('Running database validation with repair option...');
          LValidate.Repair;
        end
      else
        begin
          LLogs.Add('Running database validation (check only)...');
          LValidate.CheckOnly;
        end;

      LStopwatch.Stop;
      LLogs.Add(Format('Task completed successfully in %d ms.', [LStopwatch.ElapsedMilliseconds]));
      FAudit.WriteToolCall('validate_database', Args.ToJSON, LStopwatch.ElapsedMilliseconds, 'success');
      LLogsJson := LogsToJSONArray(LLogs);
      try
        Result := BuildResult('validate_database', 'completed', LStopwatch.ElapsedMilliseconds, LLogsJson);
      finally
        LLogsJson.Free;
      end;
    except
      on E: Exception do
        begin
          LStopwatch.Stop;
          LLogs.Add('Task failed: ' + E.Message);
          FAudit.WriteToolCall('validate_database', Args.ToJSON, LStopwatch.ElapsedMilliseconds, 'error: ' + E.Message);
          LLogsJson := LogsToJSONArray(LLogs);
          try
            Result := BuildResult('validate_database', 'failed', LStopwatch.ElapsedMilliseconds, LLogsJson, E.Message);
          finally
            LLogsJson.Free;
          end;
        end;
    end;
  finally
    LValidate.Free;
    LDriverLink.Free;
    LReceiver.Free;
    LLogs.Free;
  end;
end;

function TIBMCPManagementTools.SweepDatabase(const Args: TJSONObject): TMCPToolResult;
var
  LValidate: TFDIBValidate;
  LDriverLink: TFDPhysIBDriverLink;
  LLogs: TStringList;
  LLogsJson: TJSONArray;
  LReceiver: TServiceProgressReceiver;
  LStopwatch: TStopwatch;
begin
  if not(urDba in TIBMCPApp.Current.UserLevel) then
    Exit(TMCPToolResult.Error('Forbidden: DBA access required'));

  LLogs := TStringList.Create;
  LReceiver := TServiceProgressReceiver.Create(LLogs);
  LDriverLink := TFDPhysIBDriverLink.Create(nil);
  LValidate := TFDIBValidate.Create(nil);
  LStopwatch := TStopwatch.StartNew;
  try
    try
      LValidate.DriverLink := LDriverLink;
      LValidate.Host := FSettings.Host;
      LValidate.Protocol := ipTCPIP;
      LValidate.UserName := FSettings.UserName;
      LValidate.Password := FSettings.Password;
      LValidate.Database := FSettings.Database;
      LValidate.OnProgress := LReceiver.OnProgress;
      LLogs.Add('Running database sweep...');
      LValidate.Sweep;

      LStopwatch.Stop;
      LLogs.Add(Format('Task completed successfully in %d ms.', [LStopwatch.ElapsedMilliseconds]));
      FAudit.WriteToolCall('sweep_database', Args.ToJSON, LStopwatch.ElapsedMilliseconds, 'success');
      LLogsJson := LogsToJSONArray(LLogs);
      try
        Result := BuildResult('sweep_database', 'completed', LStopwatch.ElapsedMilliseconds, LLogsJson);
      finally
        LLogsJson.Free;
      end;
    except
      on E: Exception do
        begin
          LStopwatch.Stop;
          LLogs.Add('Task failed: ' + E.Message);
          FAudit.WriteToolCall('sweep_database', Args.ToJSON, LStopwatch.ElapsedMilliseconds, 'error: ' + E.Message);
          LLogsJson := LogsToJSONArray(LLogs);
          try
            Result := BuildResult('sweep_database', 'failed', LStopwatch.ElapsedMilliseconds, LLogsJson, E.Message);
          finally
            LLogsJson.Free;
          end;
        end;
    end;
  finally
    LValidate.Free;
    LDriverLink.Free;
    LReceiver.Free;
    LLogs.Free;
  end;
end;

end.

