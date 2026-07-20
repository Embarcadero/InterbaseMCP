unit IB.MCP.Query;

interface

uses
  System.JSON,
  Dext.AI.MCP.Attributes,
  Dext.AI.MCP.Protocol,
  Dext.AI.MCP.Tools,
  Dext.AI.MCP.Types,
  IB.MCP.ConnectionManager,
  IB.MCP.SqlValidator,
  IB.MCP.AuditLogger;

type
  /// <summary>
  /// MCP tools for SQL execution and execution-plan inspection.
  /// Routes statements to <c>ExecDataset</c> (cursor-producing) or
  /// <c>ExecStatement</c> (DML) based on <c>ReturnsCursor</c>.
  /// </summary>
  TIBMCPQueryTools = class(TMCPToolProvider)
  private
    FValidator: TIBMCPSqlValidator;
    FAudit: TIBMCPAuditLogger;
    FOwnsValidator: Boolean;
    FOwnsAudit: Boolean;

    /// <summary>Runs a cursor-returning SQL statement and serialises the result set to JSON.</summary>
    function ExecDataset(const ASql: string; const AParams: TJSONObject): string;
    /// <summary>Runs a non-cursor SQL statement and returns affected-row count as JSON.</summary>
    function ExecStatement(const ASql: string): string;
  public
    constructor Create; overload;

    destructor Destroy; override;

    [MCPTool('execute_sql', 'Execute a SQL statement on the InterBase database')]
    [MCPParam('sql', 'The SQL statement to execute')]
    function ExecuteSql(const Args: TJSONObject): TMCPToolResult; virtual;

    [MCPTool('explain_plan', 'Return the InterBase execution plan for a SQL statement')]
    [MCPParam('sql', 'The SQL statement to explain')]
    function ExplainPlan(const Args: TJSONObject): TMCPToolResult; virtual;

    [MCPTool('execute_procedure', 'Execute an InterBase stored procedure')]
    [MCPParam('proc_name', 'Stored procedure name')]
    [MCPParam('params', 'JSON object of procedure parameters', ptObject, False)]
    function ExecuteProcedure(const Args: TJSONObject): TMCPToolResult; virtual;
  end;

implementation

uses
  System.Diagnostics,
  System.SysUtils,
  FireDAC.Comp.Client,
  FireDAC.Phys.IBWrapper,
  FireDAC.Stan.Param,
  IB.MCP.DatasetHelper;

  { TIBMCPQueryTools }

constructor TIBMCPQueryTools.Create;
begin
  inherited Create;
  FValidator := TIBMCPSqlValidator.Create;
  FOwnsValidator := True;
  FAudit := TIBMCPAuditLogger.Create;
  FOwnsAudit := True;
end;

destructor TIBMCPQueryTools.Destroy;
begin
  if FOwnsAudit then
    FAudit.Free;
  if FOwnsValidator then
    FValidator.Free;
  inherited Destroy;
end;

function TIBMCPQueryTools.ExecDataset(const ASql: string; const AParams: TJSONObject): string;
var
  Connection: TFDConnection;
  Query: TFDQuery;
  Pair: TJSONPair;
begin
  Connection := TIBMCPConnectionManager.CreateConnection;
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
  Connection := TIBMCPConnectionManager.CreateConnection;
  try
    Result := '{"Affected rows": ' + Connection.ExecSQL(ASql).ToString + '}';
  finally
    Connection.Free;
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
    if FValidator.ReturnsCursor(Sql) then
      Result := TMCPToolResult.Text(ExecDataset(Sql, nil))
    else
      Result := TMCPToolResult.Text(ExecStatement(Sql));
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
  Connection := TIBMCPConnectionManager.CreateConnection;
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
  Sql: string;
  Stopwatch: TStopwatch;
  Validation: TIBMCPSqlValidationResult;
begin
  ProcName := Args.GetValue<string>('proc_name', '').Trim;
  Params := Args.GetValue<TJSONObject>('params');
  Sql := 'execute procedure ' + ProcName;
  Validation := FValidator.ValidateSql(Sql);
  if not Validation.Accepted then
    Exit(TMCPToolResult.Error(Validation.Reason));

  Stopwatch := TStopwatch.StartNew;
  try
    Result := TMCPToolResult.Text(ExecDataset(Sql, Params));
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
