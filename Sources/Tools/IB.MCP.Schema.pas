unit IB.MCP.Schema;

interface

uses
  System.JSON,
  Dext.AI.MCP.Attributes,
  Dext.AI.MCP.Protocol,
  Dext.AI.MCP.Tools,
  Dext.AI.MCP.Types,
  IB.MCP.ConnectionManager,
  IB.MCP.AuditLogger;

type
  /// <summary>
  /// MCP tools for database schema inspection.
  /// </summary>
  TIBMCPSchemaTools = class(TMCPToolProvider)
  private
    FAudit: TIBMCPAuditLogger;
    FOwnsAudit: Boolean;

    /// <summary>
    /// Runs a schema-discovery SELECT, optionally binding a single named parameter,
    /// and returns the result set serialised as a JSON string. Audit logs the call.
    /// </summary>
    function RunDiscoveryQuery(
      const AToolName, ASql: string;
      const AParamName: string = '';
      const AParamValue: string = ''
    ): string;
  public
    constructor Create; overload;

    destructor Destroy; override;

    [MCPTool('get_database_info', 'Get InterBase database information')]
    function GetDatabaseInfo(const Args: TJSONObject): TMCPToolResult; virtual;

    [MCPTool('get_tables', 'Get user tables in the InterBase database')]
    function GetTables(const Args: TJSONObject): TMCPToolResult; virtual;

    [MCPTool('get_columns', 'Get columns for an InterBase table')]
    [MCPParam('table_name', 'Table name')]
    function GetColumns(const Args: TJSONObject): TMCPToolResult; virtual;

    [MCPTool('get_indexes', 'Get indexes for an InterBase table')]
    [MCPParam('table_name', 'Table name')]
    function GetIndexes(const Args: TJSONObject): TMCPToolResult; virtual;

    [MCPTool('get_foreign_keys', 'Get foreign keys for an InterBase table')]
    [MCPParam('table_name', 'Table name')]
    function GetForeignKeys(const Args: TJSONObject): TMCPToolResult; virtual;

    [MCPTool('get_views', 'List InterBase views with source')]
    function GetViews(const Args: TJSONObject): TMCPToolResult; virtual;

    [MCPTool('get_check_constraints', 'List InterBase check constraints')]
    function GetCheckConstraints(const Args: TJSONObject): TMCPToolResult; virtual;

    [MCPTool('get_triggers', 'Inspect InterBase triggers with source code')]
    [MCPParam('table_name', 'Optional table name filter', ptString, False)]
    function GetTriggers(const Args: TJSONObject): TMCPToolResult; virtual;

    [MCPTool('get_stored_procedures', 'Inspect InterBase stored procedures with source code')]
    [MCPParam('name_filter', 'Optional procedure name filter', ptString, False)]
    function GetStoredProcedures(const Args: TJSONObject): TMCPToolResult; virtual;

    [MCPTool('get_functions', 'Inspect InterBase user defined functions')]
    function GetFunctions(const Args: TJSONObject): TMCPToolResult; virtual;

    [MCPTool('get_exceptions', 'Inspect InterBase exceptions')]
    function GetExceptions(const Args: TJSONObject): TMCPToolResult; virtual;

    [MCPTool('get_generators', 'Inspect InterBase generators and sequences')]
    function GetGenerators(const Args: TJSONObject): TMCPToolResult; virtual;

    [MCPTool('get_domains', 'Inspect InterBase domains')]
    function GetDomains(const Args: TJSONObject): TMCPToolResult; virtual;
  end;

implementation

uses
  System.Diagnostics,
  System.SysUtils,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  IB.MCP.DatasetHelper;

  { TIBMCPSchemaTools }

constructor TIBMCPSchemaTools.Create;
begin
  inherited Create;
  FAudit := TIBMCPAuditLogger.Create;
  FOwnsAudit := True;
end;

destructor TIBMCPSchemaTools.Destroy;
begin
  if FOwnsAudit then
    FAudit.Free;
  inherited Destroy;
end;

function TIBMCPSchemaTools.GetCheckConstraints(const Args: TJSONObject): TMCPToolResult;
begin
  Result := TMCPToolResult.Text(RunDiscoveryQuery('get_check_constraints', SQL_GET_CHECK_CONSTRAINTS));
end;

function TIBMCPSchemaTools.GetColumns(const Args: TJSONObject): TMCPToolResult;
begin
  Result :=
    TMCPToolResult.Text(
      RunDiscoveryQuery('get_columns', SQL_GET_COLUMNS, 'table_name', Args.GetValue<string>('table_name', ''))
    );
end;

function TIBMCPSchemaTools.GetForeignKeys(const Args: TJSONObject): TMCPToolResult;
begin
  Result :=
    TMCPToolResult.Text(
      RunDiscoveryQuery(
        'get_foreign_keys',
        SQL_GET_FOREIGN_KEYS,
        'table_name',
        Args.GetValue<string>('table_name', '')
      )
    );
end;

function TIBMCPSchemaTools.GetIndexes(const Args: TJSONObject): TMCPToolResult;
begin
  Result :=
    TMCPToolResult.Text(
      RunDiscoveryQuery('get_indexes', SQL_GET_INDEXES, 'table_name', Args.GetValue<string>('table_name', ''))
    );
end;

function TIBMCPSchemaTools.GetViews(const Args: TJSONObject): TMCPToolResult;
begin
  Result := TMCPToolResult.Text(RunDiscoveryQuery('get_views', SQL_GET_VIEWS));
end;

function TIBMCPSchemaTools.GetTables(const Args: TJSONObject): TMCPToolResult;
begin
  Result := TMCPToolResult.Text(RunDiscoveryQuery('list_tables', SQL_GET_TABLES));
end;

function TIBMCPSchemaTools.GetDatabaseInfo(const Args: TJSONObject): TMCPToolResult;
begin
  Result := TMCPToolResult.Text(RunDiscoveryQuery('get_database_details', SQL_GET_DATABASE_INFO));
end;

function TIBMCPSchemaTools.RunDiscoveryQuery(const AToolName, ASql, AParamName, AParamValue: string): string;
var
  Connection: TFDConnection;
  Query: TFDQuery;
  Params: TJSONObject;
  Stopwatch: TStopwatch;
begin
  Stopwatch := TStopwatch.StartNew;
  Connection := TIBMCPConnectionManager.CreateConnection;
  Query := TFDQuery.Create(nil);
  try
    Params := TJSONObject.Create;
    try
      try
        if AParamName <> '' then
          Params.AddPair(AParamName, AParamValue);
        Query.Connection := Connection;
        Query.SQL.Text := ASql;
        if (AParamName <> '') and (AParamValue <> '') then
          Query.ParamByName(AParamName).AsString := AParamValue.ToUpperInvariant;
        Query.Open;
        Result := TIBMCPDatasetHelper.DatasetToJson(Query);
        Stopwatch.Stop;
        FAudit.WriteToolCall(AToolName, Params.ToJSON, Stopwatch.ElapsedMilliseconds, 'success');
      except
        on E: Exception do begin
          Stopwatch.Stop;
          FAudit.WriteToolCall(AToolName, Params.ToJSON, Stopwatch.ElapsedMilliseconds, 'error: ' + E.Message);
          raise;
        end;
      end;
    finally
      Params.Free;
    end;
  finally
    Query.Free;
    Connection.Free;
  end;
end;

function TIBMCPSchemaTools.GetTriggers(const Args: TJSONObject): TMCPToolResult;
var
  TableName: string;
  Sql: string;
begin
  TableName := Args.GetValue<string>('table_name', '').Trim;
  if TableName = '' then
    Sql := SQL_GET_TRIGGERS
  else
    Sql := SQL_GET_TRIGGERS_BY_TABLE;
  Result := TMCPToolResult.Text(RunDiscoveryQuery('get_triggers', Sql, 'table_name', TableName));
end;

function TIBMCPSchemaTools.GetStoredProcedures(const Args: TJSONObject): TMCPToolResult;
var
  NameFilter: string;
  Sql: string;
begin
  NameFilter := Args.GetValue<string>('name_filter', '').Trim;
  if NameFilter = '' then
    Sql := SQL_GET_PROCEDURES
  else
    Sql := SQL_GET_PROCEDURES_BY_NAME;
  Result := TMCPToolResult.Text(RunDiscoveryQuery('get_stored_procedures', Sql, 'name_filter', NameFilter));
end;

function TIBMCPSchemaTools.GetFunctions(const Args: TJSONObject): TMCPToolResult;
begin
  Result := TMCPToolResult.Text(RunDiscoveryQuery('get_functions', SQL_GET_FUNCTIONS));
end;

function TIBMCPSchemaTools.GetExceptions(const Args: TJSONObject): TMCPToolResult;
begin
  Result := TMCPToolResult.Text(RunDiscoveryQuery('get_exceptions', SQL_GET_EXCEPTIONS));
end;

function TIBMCPSchemaTools.GetGenerators(const Args: TJSONObject): TMCPToolResult;
begin
  Result := TMCPToolResult.Text(RunDiscoveryQuery('get_generators', SQL_GET_GENERATORS));
end;

function TIBMCPSchemaTools.GetDomains(const Args: TJSONObject): TMCPToolResult;
begin
  Result := TMCPToolResult.Text(RunDiscoveryQuery('get_domains', SQL_GET_DOMAINS));
end;

end.
