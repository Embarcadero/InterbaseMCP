unit IB.MCP.Query;

interface

uses
  Dext.Json.Types,
  Dext.Core.Json.NextGen,
  Dext.AI.MCP.Attributes,
  Dext.AI.MCP.Protocol,
  Dext.AI.MCP.Tools,
  Dext.AI.MCP.Types,
  IB.MCP.SqlValidator,
  IB.MCP.AuditLogger,
  IB.MCP.Settings;

type
  /// <summary>
  /// MCP tools for SQL execution and execution-plan inspection.
  /// Routes statements to <c>ExecDataset</c> (cursor-producing) or
  /// <c>ExecStatement</c> (DML) based on statement classification.
  /// </summary>
  TIBMCPQueryTools = class(TMCPToolProvider)
  private
    FValidator: TIBMCPSqlValidator;
    FSettings: TIBMCPSettings;
    FAudit: TIBMCPAuditLogger;

    /// <summary>Runs a cursor-returning SQL statement and serialises the result set to JSON.</summary>
    function ExecDataset(const ASql: string; const AParams: TJsonObject): string;
    /// <summary>Runs a non-cursor SQL statement and returns affected-row count as JSON.</summary>
    function ExecStatement(const ASql: string): string;
    /// <summary>Execute a stored procedure that does not return a cursor.</summary>
    function ExecProcedure(const AProcName: string; const AParams: TJsonObject): string;

  public
    constructor Create; overload;
    destructor Destroy; override;

    [MCPTool('open_cursor', 'Executes a read-only SELECT query and returns the resulting dataset. Use only for retrieving data.')]
    [MCPParam('sql', 'The SELECT statement to execute.')]
    function OpenCursor(const Args: TJsonObject): TMCPToolResult; virtual;

    [MCPTool('execute_sql', 'Executes a non-query SQL statement (such as INSERT, UPDATE, DELETE, or DDL) on the InterBase database.')]
    [MCPParam('sql', 'The DML or DDL statement to execute. Do not use for SELECT statements.')]
    function ExecuteSql(const Args: TJsonObject): TMCPToolResult; virtual;

    [MCPTool('explain_plan', 'Retrieves the InterBase execution plan for a SQL query to analyze performance and index usage.')]
    [MCPParam('sql', 'The SQL statement to analyze.')]
    function ExplainPlan(const Args: TJsonObject): TMCPToolResult; virtual;

    [MCPTool('execute_procedure', 'Executes an InterBase stored procedure and returns its execution status or output variables.')]
    [MCPParam('proc_name', 'The name of the stored procedure to execute.')]
    [MCPParam('params', 'A JSON object mapping parameter names to their input values.', ptObject, False)]
    function ExecuteProcedure(const Args: TJsonObject): TMCPToolResult; virtual;
  end;

implementation

uses
  System.Diagnostics,
  System.SysUtils,
  FireDAC.Comp.Client,
  FireDAC.Phys.IBWrapper,
  FireDAC.Stan.Param,
  IB.MCP.App,
  IB.MCP.DatasetHelper;

procedure BindJsonParams(AParams: TFDParams; const AJson: TJsonObject);
var
  I: Integer;
  ParamName: string;
  Param: TFDParam;
begin
  if (AParams = nil) or (AJson = nil) then
    Exit;

  for I := 0 to AJson.Count - 1 do
  begin
    ParamName := AJson.Names[I];
    Param := AParams.ParamByName(ParamName);
    case AJson.Types[ParamName] of
      TDextJsonNodeType.jntNull:
        Param.Clear;
      TDextJsonNodeType.jntBoolean:
        Param.AsBoolean := AJson.B[ParamName];
      TDextJsonNodeType.jntNumber:
        if Frac(AJson.D[ParamName]) = 0 then
          Param.AsLargeInt := AJson.L[ParamName]
        else
          Param.AsFloat := AJson.D[ParamName];
    else
      Param.AsString := AJson.S[ParamName];
    end;
  end;
end;

{ TIBMCPQueryTools }

constructor TIBMCPQueryTools.Create;
begin
  inherited Create;
  FValidator := TIBMCPApp.Current.SqlValidator;
  FSettings := TIBMCPApp.Current.Settings;
  FAudit := TIBMCPApp.Current.AuditLogger;
end;

destructor TIBMCPQueryTools.Destroy;
begin
  inherited Destroy;
end;

function TIBMCPQueryTools.ExecDataset(const ASql: string; const AParams: TJsonObject): string;
var
  Connection: TFDConnection;
  Query: TFDQuery;
begin
  Connection := TIBMCPApp.Current.ConnectionManager.CreateConnection;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Connection;
    Query.SQL.Text := ASql;
    BindJsonParams(Query.Params, AParams);
    Query.Open;
    Result := TIBMCPDatasetHelper.DatasetToJson(Query);
  finally
    Query.Free;
    Connection.Free;
  end;
end;

function TIBMCPQueryTools.ExecStatement(const ASql: string): string;
var
  Connection: TFDConnection;
begin
  Connection := TIBMCPApp.Current.ConnectionManager.CreateConnection;
  try
    Result := '{"Affected rows": ' + Connection.ExecSQL(ASql).ToString + '}';
  finally
    Connection.Free;
  end;
end;

function TIBMCPQueryTools.ExecProcedure(const AProcName: string;
  const AParams: TJsonObject): string;
var
  Connection: TFDConnection;
  Proc: TFDStoredProc;
begin
  Connection := TIBMCPApp.Current.ConnectionManager.CreateConnection;
  Proc := TFDStoredProc.Create(nil);
  try
    Proc.Connection := Connection;
    Proc.StoredProcName := AProcName;
    Proc.Prepare;
    BindJsonParams(Proc.Params, AParams);
    Proc.ExecProc;
    Result := '{"Affected rows": ' + Proc.RowsAffected.ToString + '}';
  finally
    Proc.Free;
    Connection.Free;
  end;
end;

function TIBMCPQueryTools.OpenCursor(const Args: TJsonObject): TMCPToolResult;
var
  Sql: string;
  Stopwatch: TStopwatch;
  Validation: TIBMCPSqlValidationResult;
begin
  Sql := Args.S['sql'];
  Validation := FValidator.ValidateSql(Sql);
  if not Validation.Accepted then
    Exit(TMCPToolResult.Error(Validation.Reason));

  Stopwatch := TStopwatch.StartNew;
  try
    // VIEW statements: require view rights and return a dataset (cursor)
    if FValidator.IsViewStatement(Sql) then begin
      if not(urView in TIBMCPApp.Current.UserLevel) then
        Exit(TMCPToolResult.Error('Forbidden: VIEW access required!'));
      Result := TMCPToolResult.Text(ExecDataset(Sql, nil));
    end
    else Exit(TMCPToolResult.Error('Not a valid SELECT statement!'));

    Stopwatch.Stop;
    FAudit.WriteToolCall('open_cursor', Args.ToJson, Stopwatch.ElapsedMilliseconds, 'success');
  except
    on E: Exception do begin
      Stopwatch.Stop;
      FAudit.WriteToolCall('open_cursor', Args.ToJson, Stopwatch.ElapsedMilliseconds, 'error: ' + E.Message);
      Result := TMCPToolResult.Error(E.Message);
    end;
  end;
end;

function TIBMCPQueryTools.ExecuteSql(const Args: TJsonObject): TMCPToolResult;
var
  Sql: string;
  Stopwatch: TStopwatch;
  Validation: TIBMCPSqlValidationResult;
begin
  Sql := Args.S['sql'];
  Validation := FValidator.ValidateSql(Sql);
  if not Validation.Accepted then
    Exit(TMCPToolResult.Error(Validation.Reason));

  Stopwatch := TStopwatch.StartNew;
  try
    // CRUD statements: require crud rights and execute as non-cursor
    if FValidator.IsCrudStatement(Sql) then begin
      if not(urCrud in TIBMCPApp.Current.UserLevel) then
        Exit(TMCPToolResult.Error('Forbidden: CRUD access required!'));
      Result := TMCPToolResult.Text(ExecStatement(Sql));

    // DBA statements: require DBA rights and execute as non-cursor
    end else if FValidator.IsDbaStatement(Sql) then begin
      if not(urDba in TIBMCPApp.Current.UserLevel) then
        Exit(TMCPToolResult.Error('Forbidden: DBA access required!'));
      Result := TMCPToolResult.Text(ExecStatement(Sql));

    end else Exit(TMCPToolResult.Error('Not a valid CRUD or DDL statement!'));

    Stopwatch.Stop;
    FAudit.WriteToolCall('execute_sql', Args.ToJson, Stopwatch.ElapsedMilliseconds, 'success');
  except
    on E: Exception do begin
      Stopwatch.Stop;
      FAudit.WriteToolCall('execute_sql', Args.ToJson, Stopwatch.ElapsedMilliseconds, 'error: ' + E.Message);
      Result := TMCPToolResult.Error(E.Message);
    end;
  end;
end;

function TIBMCPQueryTools.ExplainPlan(const Args: TJsonObject): TMCPToolResult;
var
  ExecutionPlan: string;
  Json: TJsonObject;
  Connection: TFDConnection;
  Query: TFDQuery;
  Statement: TIBStatement;
  Sql: string;
  Stopwatch: TStopwatch;
  Validation: TIBMCPSqlValidationResult;
begin
  Sql := Args.S['sql'];
  Validation := FValidator.ValidateSql(Sql);
  if not Validation.Accepted then
    Exit(TMCPToolResult.Error(Validation.Reason));

  Stopwatch := TStopwatch.StartNew;
  Connection := TIBMCPApp.Current.ConnectionManager.CreateConnection;
  Query := TFDQuery.Create(nil);
  try
    try
      Query.Connection := Connection;
      Query.SQL.Text := Sql;
      Query.Prepare;
      ExecutionPlan := '';
      if Assigned(Query.Command.CommandIntf) and Assigned(Query.Command.CommandIntf.CliObj) then begin
        Statement := TIBStatement(Query.Command.CommandIntf.CliObj);
        ExecutionPlan := Statement.sql_get_plan;
        if ExecutionPlan = '' then
          ExecutionPlan := Statement.sql_explain_plan;
      end;
      Json := TJsonObject.Create;
      try
        Json.B['prepared'] := Query.Prepared;
        Json.S['sql'] := Sql;
        Json.S['plan'] := ExecutionPlan;
        Result := TMCPToolResult.Text(Json.ToJson);
      finally
        Json.Free;
      end;
      Stopwatch.Stop;
      FAudit.WriteToolCall('explain_plan', Args.ToJson, Stopwatch.ElapsedMilliseconds, 'success');
    except
      on E: Exception do begin
        Stopwatch.Stop;
        FAudit.WriteToolCall('explain_plan', Args.ToJson, Stopwatch.ElapsedMilliseconds, 'error: ' + E.Message);
        Result := TMCPToolResult.Error(E.Message);
      end;
    end;
  finally
    Query.Free;
    Connection.Free;
  end;
end;

function TIBMCPQueryTools.ExecuteProcedure(const Args: TJsonObject): TMCPToolResult;
var
  Params: TJsonObject;
  ProcName: string;
  Stopwatch: TStopwatch;
begin
  ProcName := Args.S['proc_name'].Trim;
  if Args.Types['params'] = TDextJsonNodeType.jntObject then
    Params := Args.O['params']
  else
    Params := nil;

  Stopwatch := TStopwatch.StartNew;
  try
    if not(urCrud in TIBMCPApp.Current.UserLevel) then
      Exit(TMCPToolResult.Error('Forbidden: CRUD access required'));
    Result := TMCPToolResult.Text(ExecProcedure(ProcName, Params));
    Stopwatch.Stop;
    FAudit.WriteToolCall('execute_procedure', Args.ToJson, Stopwatch.ElapsedMilliseconds, 'success');
  except
    on E: Exception do begin
      Stopwatch.Stop;
      FAudit.WriteToolCall('execute_procedure', Args.ToJson, Stopwatch.ElapsedMilliseconds, 'error: ' + E.Message);
      Result := TMCPToolResult.Error(E.Message);
    end;
  end;
end;

end.


