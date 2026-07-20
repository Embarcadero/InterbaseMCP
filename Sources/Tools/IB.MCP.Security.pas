unit IB.MCP.Security;

interface

uses
  System.JSON,
  System.DateUtils,
  Dext.AI.MCP.Attributes,
  Dext.AI.MCP.Protocol,
  Dext.AI.MCP.Tools,
  Dext.AI.MCP.Types,
  IB.MCP.ConnectionManager,
  IB.MCP.SqlValidator,
  IB.MCP.AuditLogger,
  IB.MCP.Settings;

type
  /// <summary>
  /// MCP tools for security and audit access.
  /// </summary>
  TIBMCPSecurityTools = class(TMCPToolProvider)
  private
    FValidator: TIBMCPSqlValidator;
    FAudit: TIBMCPAuditLogger;
    FSettings: TIBMCPSettings;
    FOwnsValidator: Boolean;
    FOwnsAudit: Boolean;
    /// <summary>Executes a read-only discovery SQL statement and returns results as a JSON string.</summary>
    function QueryJson(const ASql: string; const AParamName: string = ''; const AParamValue: string = ''): string;
  public
    constructor Create; overload;

    destructor Destroy; override;

    [MCPTool('get_user_privileges', 'List InterBase privileges for a user')]
    [MCPParam('user_name', 'User name')]
    function GetUserPrivileges(const Args: TJSONObject): TMCPToolResult; virtual;

    [MCPTool('list_roles', 'List user-defined InterBase roles')]
    function ListRoles(const Args: TJSONObject): TMCPToolResult; virtual;

    [MCPTool('get_role_members', 'List InterBase role members')]
    [MCPParam('role_name', 'Optional role name filter', ptString, False)]
    function GetRoleMembers(const Args: TJSONObject): TMCPToolResult; virtual;

    [MCPTool('get_audit_log', 'Read the MCP todays audit log with paging and filters')]
    [MCPParam('tool_name', 'Optional tool name filter', ptString, False)]
    [MCPParam('outcome', 'Optional outcome text filter', ptString, False)]
    [MCPParam('offset', 'Rows to skip', ptInteger, False)]
    [MCPParam('limit', 'Maximum rows to return', ptInteger, False)]
    function GetAuditLog(const Args: TJSONObject): TMCPToolResult; virtual;
  end;

implementation

uses
  System.Classes,
  System.IOUtils,
  System.SysUtils,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  IB.MCP.DatasetHelper;

  { TIBMCPSecurityTools }

constructor TIBMCPSecurityTools.Create;
begin
  inherited Create;
  FSettings := TIBMCPSettings.Create;
  FValidator := TIBMCPSqlValidator.Create;
  FOwnsValidator := True;
  FAudit := TIBMCPAuditLogger.Create;
  FOwnsAudit := True;
end;

destructor TIBMCPSecurityTools.Destroy;
begin
  if FOwnsAudit then
    FAudit.Free;
  if FOwnsValidator then
    FValidator.Free;
  FSettings.Free;
  inherited Destroy;
end;

function TIBMCPSecurityTools.QueryJson(const ASql, AParamName, AParamValue: string): string;
var
  Connection: TFDConnection;
  Query: TFDQuery;
begin
  Connection := TIBMCPConnectionManager.CreateConnection;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Connection;
    Query.SQL.Text := ASql;
    if (AParamName <> '') and (AParamValue <> '') then
      Query.ParamByName(AParamName).AsString := AParamValue.ToUpperInvariant;
    Query.Open;
    Result := TIBMCPDatasetHelper.DatasetToJson(Query);
  finally
    Query.Free;
    Connection.Free;
  end;
end;

function TIBMCPSecurityTools.GetUserPrivileges(const Args: TJSONObject): TMCPToolResult;
begin
  try
    Result :=
      TMCPToolResult.Text(QueryJson(SQL_GET_USER_PRIVILEGES, 'user_name', Args.GetValue<string>('user_name', '')));
  except
    on E: Exception do
      Result := TMCPToolResult.Error(E.Message);
  end;
end;

function TIBMCPSecurityTools.ListRoles(const Args: TJSONObject): TMCPToolResult;
begin
  try
    Result := TMCPToolResult.Text(QueryJson(SQL_LIST_ROLES));
  except
    on E: Exception do
      Result := TMCPToolResult.Error(E.Message);
  end;
end;

function TIBMCPSecurityTools.GetRoleMembers(const Args: TJSONObject): TMCPToolResult;
var
  RoleName: string;
  Sql: string;
begin
  RoleName := Args.GetValue<string>('role_name', '');
  if RoleName = '' then
    Sql := SQL_GET_ROLE_MEMBERS
  else
    Sql := SQL_GET_ROLE_MEMBERS_BY_ROLE;
  try
    Result := TMCPToolResult.Text(QueryJson(Sql, 'role_name', RoleName));
  except
    on E: Exception do
      Result := TMCPToolResult.Error(E.Message);
  end;
end;

function TIBMCPSecurityTools.GetAuditLog(const Args: TJSONObject): TMCPToolResult;
var
  FileName: string;
  Lines: TStringList;
  Arr: TJSONArray;
  I, Added, Offset, Limit: Integer;
  Line, ToolName, Outcome: string;
begin
  Offset := Args.GetValue<Integer>('offset', 0);
  Limit := Args.GetValue<Integer>('limit', 100);
  ToolName := Args.GetValue<string>('tool_name', '');
  Outcome := Args.GetValue<string>('outcome', '');
  Arr := TJSONArray.Create;
  Lines := TStringList.Create;
  try
    FileName := ChangeFileExt(FSettings.AuditPath, '.' + FormatDateTime('yyyymmdd', Today) + '.jsonl');
    if TFile.Exists(FileName) then
      Lines.LoadFromFile(FileName, TEncoding.UTF8);
    Added := 0;
    for I := Offset to Lines.Count - 1 do begin
      Line := Lines[I];
      if (ToolName <> '') and not Line.Contains('"tool":"' + ToolName + '"') then
        Continue;
      if (Outcome <> '') and not Line.Contains(Outcome) then
        Continue;
      Arr.Add(Line);
      Inc(Added);
      if Added >= Limit then
        Break;
    end;
    Result := TMCPToolResult.Text(Arr.ToJSON);
  finally
    Lines.Free;
    Arr.Free;
  end;
end;

end.
