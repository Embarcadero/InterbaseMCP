unit IB.Tools.Performance;

interface

uses
  System.JSON,
  Dext.AI.MCP.Attributes,
  Dext.AI.MCP.Tools,
  Dext.AI.MCP.Types,
  IB.ConnectionManager;

type
  /// <summary>
  /// Provides MCP tools for retrieving Interbase performance and statistics monitoring data.
  /// </summary>
  TIBStatisticsTools = class(TMCPToolProvider)
  private
    function QueryJson(const ASql: string; AMaxRows: Integer = 1000): string;
  public
    /// <summary>
    /// Initializes the statistics tools provider.
    /// </summary>
    constructor Create; overload;

    [MCPTool('stat_attachments', 'Returns one row for each connection to a database')]
    function StatAttachments(const Args: TJSONObject): TMCPToolResult; virtual;

    [MCPTool('stat_database', 'Returns one row for each database you are attached to')]
    function StatDatabase(const Args: TJSONObject): TMCPToolResult; virtual;

    [MCPTool('stat_heaps', 'Returns one row for each entry in the InterBase Random and Block heap')]
    function StatHeaps(const Args: TJSONObject): TMCPToolResult; virtual;

    [MCPTool('stat_indices', 'Returns one row for each index loaded into database cache')]
    function StatIndices(const Args: TJSONObject): TMCPToolResult; virtual;

    [MCPTool('stat_pool_blocks', 'Returns one row for each block of memory in each pool')]
    function StatPoolBlocks(const Args: TJSONObject): TMCPToolResult; virtual;

    [MCPTool('stat_pools', 'Returns one row for each current memory pool')]
    function StatPools(const Args: TJSONObject): TMCPToolResult; virtual;

    [MCPTool('stat_procedures', 'Returns one row for each procedure loaded into database cache')]
    function StatProcedures(const Args: TJSONObject): TMCPToolResult; virtual;

    [MCPTool('stat_relations', 'Returns one row for each relation loaded into database cache')]
    function StatRelations(const Args: TJSONObject): TMCPToolResult; virtual;

    [MCPTool('stat_statements', 'Returns one row for each statement currently executing for any current connection')]
    function StatStatements(const Args: TJSONObject): TMCPToolResult; virtual;

    [MCPTool('stat_transactions', 'Returns one row for each transaction that is active or in limbo')]
    function StatTransactions(const Args: TJSONObject): TMCPToolResult; virtual;

    [MCPTool('stat_triggers', 'Returns one row for each trigger loaded into database cache')]
    function StatTriggers(const Args: TJSONObject): TMCPToolResult; virtual;
  end;

implementation

uses
  System.SysUtils,
  FireDAC.Comp.Client,
  IB.DatasetHelper;

constructor TIBStatisticsTools.Create;
begin
  inherited Create;
end;

function TIBStatisticsTools.QueryJson(const ASql: string; AMaxRows: Integer): string;
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := TIBConnectionManager.Instance.Connection;
    Query.SQL.Text := ASql;
    Query.Open;
    Result := TIBDatasetHelper.DatasetToJson(Query, AMaxRows);
  finally
    Query.Free;
  end;
end;

function TIBStatisticsTools.StatAttachments(const Args: TJSONObject): TMCPToolResult;
begin
  try
    Result := TMCPToolResult.Text(QueryJson(SQL_MONITOR_ATTACHMENTS));
  except
    on E: Exception do
      Result := TMCPToolResult.Error(E.Message);
  end;
end;

function TIBStatisticsTools.StatDatabase(const Args: TJSONObject): TMCPToolResult;
begin
  try
    Result := TMCPToolResult.Text(QueryJson(SQL_MONITOR_DATABASE));
  except
    on E: Exception do
      Result := TMCPToolResult.Error(E.Message);
  end;
end;

function TIBStatisticsTools.StatHeaps(const Args: TJSONObject): TMCPToolResult;
begin
  try
    Result := TMCPToolResult.Text(QueryJson(SQL_MONITOR_HEAPS));
  except
    on E: Exception do
      Result := TMCPToolResult.Error(E.Message);
  end;
end;

function TIBStatisticsTools.StatIndices(const Args: TJSONObject): TMCPToolResult;
begin
  try
    Result := TMCPToolResult.Text(QueryJson(SQL_MONITOR_INDICES));
  except
    on E: Exception do
      Result := TMCPToolResult.Error(E.Message);
  end;
end;

function TIBStatisticsTools.StatPoolBlocks(const Args: TJSONObject): TMCPToolResult;
begin
  try
    Result := TMCPToolResult.Text(QueryJson(SQL_MONITOR_POOL_BLOCKS));
  except
    on E: Exception do
      Result := TMCPToolResult.Error(E.Message);
  end;
end;

function TIBStatisticsTools.StatPools(const Args: TJSONObject): TMCPToolResult;
begin
  try
    Result := TMCPToolResult.Text(QueryJson(SQL_MONITOR_POOLS));
  except
    on E: Exception do
      Result := TMCPToolResult.Error(E.Message);
  end;
end;

function TIBStatisticsTools.StatProcedures(const Args: TJSONObject): TMCPToolResult;
begin
  try
    Result := TMCPToolResult.Text(QueryJson(SQL_MONITOR_PROCEDURES));
  except
    on E: Exception do
      Result := TMCPToolResult.Error(E.Message);
  end;
end;

function TIBStatisticsTools.StatRelations(const Args: TJSONObject): TMCPToolResult;
begin
  try
    Result := TMCPToolResult.Text(QueryJson(SQL_MONITOR_RELATIONS));
  except
    on E: Exception do
      Result := TMCPToolResult.Error(E.Message);
  end;
end;

function TIBStatisticsTools.StatStatements(const Args: TJSONObject): TMCPToolResult;
begin
  try
    Result := TMCPToolResult.Text(QueryJson(SQL_MONITOR_STATEMENTS));
  except
    on E: Exception do
      Result := TMCPToolResult.Error(E.Message);
  end;
end;

function TIBStatisticsTools.StatTransactions(const Args: TJSONObject): TMCPToolResult;
begin
  try
    Result := TMCPToolResult.Text(QueryJson(SQL_MONITOR_TRANSACTIONS));
  except
    on E: Exception do
      Result := TMCPToolResult.Error(E.Message);
  end;
end;

function TIBStatisticsTools.StatTriggers(const Args: TJSONObject): TMCPToolResult;
begin
  try
    Result := TMCPToolResult.Text(QueryJson(SQL_MONITOR_TRIGGERS));
  except
    on E: Exception do
      Result := TMCPToolResult.Error(E.Message);
  end;
end;

end.
