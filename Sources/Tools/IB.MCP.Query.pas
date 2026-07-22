unit IB.MCP.Query;

interface

uses
  System.JSON,
  Dext.AI.MCP.Attributes,
  Dext.AI.MCP.Protocol,
  Dext.AI.MCP.Tools,
  Dext.AI.MCP.Types,
  IB.MCP.SqlValidator,
  IB.MCP.AuditLogger,
  IB.MCP.Settings;

  /// MCP tools for SQL execution and execution-plan inspection.
  /// Routes statements to <c>ExecDataset</c> (cursor-producing) or
  /// <c>ExecStatement</c> (DML) based on <c>ReturnsCursor</c>.
  /// </summary>
  type
    TIBMCPQueryTools = class(TMCPToolProvider)
    private
      FValidator: TIBMCPSqlValidator;
      FSettings: TIBMCPSettings;
      FAudit: TIBMCPAuditLogger;

      /// <summary>Runs a cursor-returning SQL statement and serialises the result set to JSON.</summary>
      function ExecDataset(const ASql: string; const AParams: TJSONObject): string;
      /// <summary>Runs a non-cursor SQL statement and returns affected-row count as JSON.</summary>
      function ExecStatement(const ASql: string): string;
      /// <summary>Execute a stored procedure that does not return a cursor.</summary>
      function ExecProcedure(const AProcName: string; const AParams: TJSONObject): string;

    public
      constructor Create; overload;

      destructor Destroy; override;

      [MCPTool('open_cursor', 'Executes a read-only SELECT query and returns the resulting dataset. Use only for retrieving data.')]
      [MCPParam('sql', 'The SELECT statement to execute.')]
      function OpenCursor(const Args: TJSONObject): TMCPToolResult; virtual;

      [MCPTool('execute_sql', 'Executes a non-query SQL statement (such as INSERT, UPDATE, DELETE, or DDL) on the InterBase database.')]
      [MCPParam('sql', 'The DML or DDL statement to execute. Do not use for SELECT statements.')]
      function ExecuteSql(const Args: TJSONObject): TMCPToolResult; virtual;

      [MCPTool('explain_plan', 'Retrieves the InterBase execution plan for a SQL query to analyze performance and index usage.')]
      [MCPParam('sql', 'The SQL statement to analyze.')]
      function ExplainPlan(const Args: TJSONObject): TMCPToolResult; virtual;

      [MCPTool('execute_procedure', 'Executes an InterBase stored procedure and returns its execution status or output variables.')]
      [MCPParam('proc_name', 'The name of the stored procedure to execute.')]
      [MCPParam('params', 'A JSON object mapping parameter names to their input values.', ptObject, False)]
      function ExecuteProcedure(const Args: TJSONObject): TMCPToolResult; virtual;
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

function TIBMCPQueryTools.ExecDataset(const ASql: string; const AParams: TJSONObject): string;
var
  Connection: TFDConnection;
  Query: TFDQuery;
  Pair: TJSONPair;
begin
  Connection := TIBMCPApp.Current.ConnectionManager.CreateConnection;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Connection;
    Query.SQL.Text := ASql;
    if Assigned(AParams) then
      for Pair in AParams do
        Query.ParamByName(Pair.JsonString.Value).Value := Pair.JsonValue.Value;
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
  const AParams: TJSONObject): string;
var
  Connection: TFDConnection;
  Proc: TFDStoredProc;
  Pair: TJSONPair;
begin
  Connection := TIBMCPApp.Current.ConnectionManager.CreateConnection;
  Proc := TFDStoredProc.Create(nil);
  try
    Proc.Connection := Connection;
    Proc.StoredProcName := AProcName;
    Proc.Prepare;
    if Assigned(AParams) then
      for Pair in AParams do
        Proc.ParamByName(Pair.JsonString.Value).Value := Pair.JsonValue.Value;
    Proc.ExecProc;
    Result := '{"Affected rows": ' + Proc.RowsAffected.ToString + '}';
  finally
    Proc.Free;
    Connection.Free;
  end;
end;

function TIBMCPQueryTools.OpenCursor(const Args: TJSONObject): TMCPToolResult;
var
  Sql: string;
  Stopwatch: TStopwatch;
  Validation: TIBMCPSqlValidationResult;
begin
  Sql := Args.GetValue<string>('sql', '');
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
    FAudit.WriteToolCall('open_cursor', Args.ToJSON, Stopwatch.ElapsedMilliseconds, 'success');
  except
    on E: Exception do begin
      Stopwatch.Stop;
      FAudit.WriteToolCall('open_cursor', Args.ToJSON, Stopwatch.ElapsedMilliseconds, 'error: ' + E.Message);
      Result := TMCPToolResult.Error(E.Message);
    end;
  end;
end;

function TIBMCPQueryTools.ExecuteSql(const Args: TJSONObject): TMCPToolResult;
var
  Sql: string;
  Stopwatch: TStopwatch;
  Validation: TIBMCPSqlValidationResult;
begin
  Sql := Args.GetValue<string>('sql', '');
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
    FAudit.WriteToolCall('execute_sql', Args.ToJSON, Stopwatch.ElapsedMilliseconds, 'success');
  except
    on E: Exception do begin
      Stopwatch.Stop;
      FAudit.WriteToolCall('execute_sql', Args.ToJSON, Stopwatch.ElapsedMilliseconds, 'error: ' + E.Message);
      Result := TMCPToolResult.Error(E.Message);
    end;
  end;
end;

function TIBMCPQueryTools.ExplainPlan(const Args: TJSONObject): TMCPToolResult;
var
  ExecutionPlan: string;
  Json: TJSONObject;
  Connection: TFDConnection;
  Query: TFDQuery;
  Statement: TIBStatement;
  Sql: string;
  Stopwatch: TStopwatch;
  Validation: TIBMCPSqlValidationResult;
begin
  Sql := Args.GetValue<string>('sql', '');
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
      Json := TJSONObject.Create;
      try
        Json.AddPair('prepared', TJSONBool.Create(Query.Prepared));
        Json.AddPair('sql', Sql);
        Json.AddPair('plan', ExecutionPlan);
        Result := TMCPToolResult.Text(Json.ToJSON);
      finally
        Json.Free;
      end;
      Stopwatch.Stop;
      FAudit.WriteToolCall('explain_plan', Args.ToJSON, Stopwatch.ElapsedMilliseconds, 'success');
    except
      on E: Exception do begin
        Stopwatch.Stop;
        FAudit.WriteToolCall('explain_plan', Args.ToJSON, Stopwatch.ElapsedMilliseconds, 'error: ' + E.Message);
        Result := TMCPToolResult.Error(E.Message);
      end;
    end;
  finally
    Query.Free;
    Connection.Free;
  end;
end;

function TIBMCPQueryTools.ExecuteProcedure(const Args: TJSONObject): TMCPToolResult;
var
  Params: TJSONObject;
  ProcName: string;
  Stopwatch: TStopwatch;
begin
  ProcName := Args.GetValue<string>('proc_name', '').Trim;
  Params := Args.GetValue<TJSONObject>('params');

  Stopwatch := TStopwatch.StartNew;
  try
    if not(urCrud in TIBMCPApp.Current.UserLevel) then
      Exit(TMCPToolResult.Error('Forbidden: CRUD access required'));
    Result := TMCPToolResult.Text(ExecProcedure(ProcName, Params));
    Stopwatch.Stop;
    FAudit.WriteToolCall('execute_procedure', Args.ToJSON, Stopwatch.ElapsedMilliseconds, 'success');
  except
    on E: Exception do begin
      Stopwatch.Stop;
      FAudit.WriteToolCall('execute_procedure', Args.ToJSON, Stopwatch.ElapsedMilliseconds, 'error: ' + E.Message);
      Result := TMCPToolResult.Error(E.Message);
    end;
  end;
end;

end.


