unit IB.Tools.Query;

interface

uses
  System.JSON,
  Dext.AI.MCP.Attributes,
  Dext.AI.MCP.Protocol,
  Dext.AI.MCP.Tools,
  Dext.AI.MCP.Types,
  IB.ConnectionManager,
  IB.SqlValidator,
  IB.AuditLogger;

type
  /// <summary>
  /// MCP tools for SQL execution and plans.
  /// </summary>
  TIBQueryTools = class(TMCPToolProvider)
  private
    FValidator: TSqlValidator;
    FAudit: TAuditLogger;
    FOwnsValidator: Boolean;
    FOwnsAudit: Boolean;

    function ExecuteDatasetJson(const ASql: string; const AParams: TJSONObject; AMaxRows: Integer): string;
  public
    constructor Create; overload;

    destructor Destroy; override;

    [MCPTool('execute_sql', 'Execute a SQL SELECT or EXECUTE PROCEDURE on the InterBase database')]
    [MCPParam('sql', 'The SQL statement to execute')]
    [MCPParam('max_rows', 'Maximum rows to return (default 200)', ptInteger, False)]
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
  IB.DatasetHelper;

  { TIBQueryTools }

constructor TIBQueryTools.Create;
begin
  inherited Create;
  FValidator := TSqlValidator.Create;
  FOwnsValidator := True;
  FAudit := TAuditLogger.Create;
  FOwnsAudit := True;
end;

destructor TIBQueryTools.Destroy;
begin
  if FOwnsAudit then
    FAudit.Free;
  if FOwnsValidator then
    FValidator.Free;
  inherited Destroy;
end;

function TIBQueryTools.ExecuteDatasetJson(const ASql: string; const AParams: TJSONObject; AMaxRows: Integer): string;
var
  Connection: TFDConnection;
  Query: TFDQuery;
  Pair: TJSONPair;
begin
  Connection := TIBConnectionManager.CreateConnection;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Connection;
    Query.SQL.Text := ASql;
    if Assigned(AParams) then
      for Pair in AParams do
        Query.ParamByName(Pair.JsonString.Value).Value := Pair.JsonValue.Value;
    Query.Open;
    Result := TIBDatasetHelper.DatasetToJson(Query);
  finally
    Query.Free;
    Connection.Free;
  end;
end;

function TIBQueryTools.ExecuteProcedure(const Args: TJSONObject): TMCPToolResult;
var
  Params: TJSONObject;
  ProcName: string;
  Sql: string;
  Stopwatch: TStopwatch;
  Validation: TSqlValidationResult;
begin
  ProcName := Args.GetValue<string>('proc_name', '').Trim;
  Params := Args.GetValue<TJSONObject>('params');
  Sql := 'execute procedure ' + ProcName;
  Validation := FValidator.ValidateSql(Sql);
  if not Validation.Accepted then
    Exit(TMCPToolResult.Error(Validation.Reason));

  Stopwatch := TStopwatch.StartNew;
  try
    Result := TMCPToolResult.Text(ExecuteDatasetJson(Sql, Params, 200));
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

function TIBQueryTools.ExecuteSql(const Args: TJSONObject): TMCPToolResult;
var
  Sql: string;
  MaxRows: Integer;
  Stopwatch: TStopwatch;
  Validation: TSqlValidationResult;
begin
  Sql := Args.GetValue<string>('sql', '');
  MaxRows := Args.GetValue<Integer>('max_rows', 200);
  Validation := FValidator.ValidateSql(Sql, False);
  if not Validation.Accepted then
    Exit(TMCPToolResult.Error(Validation.Reason));

  Stopwatch := TStopwatch.StartNew;
  try
    Result := TMCPToolResult.Text(ExecuteDatasetJson(Sql, nil, MaxRows));
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

function TIBQueryTools.ExplainPlan(const Args: TJSONObject): TMCPToolResult;
var
  ExecutionPlan: string;
  Json: TJSONObject;
  Connection: TFDConnection;
  Query: TFDQuery;
  Statement: TIBStatement;
  Sql: string;
  Stopwatch: TStopwatch;
  Validation: TSqlValidationResult;
begin
  Sql := Args.GetValue<string>('sql', '');
  Validation := FValidator.ValidateSql(Sql, False);
  if not Validation.Accepted then
    Exit(TMCPToolResult.Error(Validation.Reason));

  Stopwatch := TStopwatch.StartNew;
  Connection := TIBConnectionManager.CreateConnection;
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

end.

