unit IB.Tools.Security;

interface

uses
  System.JSON,
  System.DateUtils,
  Dext.AI.MCP.Attributes,
  Dext.AI.MCP.Protocol,
  Dext.AI.MCP.Tools,
  Dext.AI.MCP.Types,
  IB.ConnectionManager,
  IB.SqlValidator,
  IB.AuditLogger,
  IB.MCP.Settings;

type
  /// <summary>
  /// Provides MCP tools for database security, privileges, and audit log retrieval.
  /// </summary>
  TIBSecurityTools = class(TMCPToolProvider)
  private
    FValidator: TSqlValidator;
    FAudit: TAuditLogger;
    FSettings: TIBSettings;
    FOwnsValidator: Boolean;
    FOwnsAudit: Boolean;
    function QueryJson(const ASql: string; const AParamName: string = ''; const AParamValue: string = ''): string;
  public
    /// <summary>
    /// Initializes the security tools provider and its dependencies.
    /// </summary>
    constructor Create; overload;
    
    /// <summary>
    /// Destroys the security tools provider and frees owned resources.
    /// </summary>
    destructor Destroy; override;

    [MCPTool('validate_sql', 'Validate SQL without executing it')]
    [MCPParam('sql', 'SQL statement to validate')]
    [MCPParam('allow_writes', 'Allow write statements for this validation', ptBoolean, False)]
    function ValidateSql(const Args: TJSONObject): TMCPToolResult; virtual;

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
  IB.DatasetHelper;

constructor TIBSecurityTools.Create;
begin
  inherited Create;
  FSettings := TIBSettings.Create;
  FValidator := TSqlValidator.Create;
  FOwnsValidator := True;
  FAudit := TAuditLogger.Create;
  FOwnsAudit := True;
end;

destructor TIBSecurityTools.Destroy;
begin
  if FOwnsAudit then
    FAudit.Free;
  if FOwnsValidator then
    FValidator.Free;
  FSettings.Free;
  inherited Destroy;
end;

function TIBSecurityTools.QueryJson(const ASql, AParamName, AParamValue: string): string;
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := TIBConnectionManager.Instance.Connection;
    Query.SQL.Text := ASql;
    if (AParamName <> '') and (AParamValue <> '') then
      Query.ParamByName(AParamName).AsString := AParamValue.ToUpperInvariant;
    Query.Open;
    Result := TIBDatasetHelper.DatasetToJson(Query, 500);
  finally
    Query.Free;
  end;
end;

function TIBSecurityTools.ValidateSql(const Args: TJSONObject): TMCPToolResult;
var
  Json: TJSONObject;
  Validation: TSqlValidationResult;
begin
  Validation := FValidator.ValidateSql(Args.GetValue<string>('sql', ''), Args.GetValue<Boolean>('allow_writes', False));
  Json := TJSONObject.Create;
  try
    Json.AddPair('accepted', TJSONBool.Create(Validation.Accepted));
    Json.AddPair('reason', Validation.Reason);
    Json.AddPair('warning', Validation.Warning);
    Result := TMCPToolResult.Text(Json.ToJSON);
  finally
    Json.Free;
  end;
end;

function TIBSecurityTools.GetUserPrivileges(const Args: TJSONObject): TMCPToolResult;
begin
  try
    Result :=
        TMCPToolResult.Text(QueryJson(SQL_GET_USER_PRIVILEGES, 'user_name', Args.GetValue<string>('user_name', '')));
  except
    on E: Exception do
      Result := TMCPToolResult.Error(E.Message);
  end;
end;

function TIBSecurityTools.ListRoles(const Args: TJSONObject): TMCPToolResult;
begin
  try
    Result := TMCPToolResult.Text(QueryJson(SQL_LIST_ROLES));
  except
    on E: Exception do
      Result := TMCPToolResult.Error(E.Message);
  end;
end;

function TIBSecurityTools.GetRoleMembers(const Args: TJSONObject): TMCPToolResult;
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

function TIBSecurityTools.GetAuditLog(const Args: TJSONObject): TMCPToolResult;
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
