unit IB.MCP.Statistics;

interface

uses
  Dext.Core.Json.NextGen,
  Dext.AI.MCP.Attributes,
  Dext.AI.MCP.Tools,
  Dext.AI.MCP.Types;

type
  /// <summary>
  /// MCP tools for InterBase statistics views.
  /// </summary>
  TIBMCPStatisticsTools = class(TMCPToolProvider)
  private
    /// <summary>Executes a monitoring-view SELECT and returns the result set as a JSON string.</summary>
    function QueryJson(const ASql: string; AMaxRows: Integer = 1000): string;
  public
    constructor Create; overload;

    [MCPTool('stat_attachments', 'Returns one row for each connection to a database')]
    function StatAttachments(const Args: TJsonObject): TMCPToolResult; virtual;

    [MCPTool('stat_database', 'Returns one row for each database you are attached to')]
    function StatDatabase(const Args: TJsonObject): TMCPToolResult; virtual;

    [MCPTool('stat_heaps', 'Returns one row for each entry in the InterBase Random and Block heap')]
    function StatHeaps(const Args: TJsonObject): TMCPToolResult; virtual;

    [MCPTool('stat_indices', 'Returns one row for each index loaded into database cache')]
    function StatIndices(const Args: TJsonObject): TMCPToolResult; virtual;

    [MCPTool('stat_pool_blocks', 'Returns one row for each block of memory in each pool')]
    function StatPoolBlocks(const Args: TJsonObject): TMCPToolResult; virtual;

    [MCPTool('stat_pools', 'Returns one row for each current memory pool')]
    function StatPools(const Args: TJsonObject): TMCPToolResult; virtual;

    [MCPTool('stat_procedures', 'Returns one row for each procedure loaded into database cache')]
    function StatProcedures(const Args: TJsonObject): TMCPToolResult; virtual;

    [MCPTool('stat_relations', 'Returns one row for each relation loaded into database cache')]
    function StatRelations(const Args: TJsonObject): TMCPToolResult; virtual;

    [MCPTool('stat_statements', 'Returns one row for each statement currently executing for any current connection')]
    function StatStatements(const Args: TJsonObject): TMCPToolResult; virtual;

    [MCPTool('stat_transactions', 'Returns one row for each transaction that is active or in limbo')]
    function StatTransactions(const Args: TJsonObject): TMCPToolResult; virtual;

    [MCPTool('stat_triggers', 'Returns one row for each trigger loaded into database cache')]
    function StatTriggers(const Args: TJsonObject): TMCPToolResult; virtual;
  end;

implementation

uses
  System.SysUtils,
  FireDAC.Comp.Client,
  IB.MCP.App,
  IB.MCP.DatasetHelper;

  { TIBMCPStatisticsTools }

constructor TIBMCPStatisticsTools.Create;
begin
  inherited Create;
end;

function TIBMCPStatisticsTools.QueryJson(const ASql: string; AMaxRows: Integer): string;
var
  Connection: TFDConnection;
  Query: TFDQuery;
begin
  Connection := TIBMCPApp.Current.ConnectionManager.CreateConnection;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Connection;
    Query.SQL.Text := ASql;
    Query.Open;
    Result := TIBMCPDatasetHelper.DatasetToJson(Query);
  finally
    Query.Free;
    Connection.Free;
  end;
end;

function TIBMCPStatisticsTools.StatAttachments(const Args: TJsonObject): TMCPToolResult;
begin
  try
    Result := TMCPToolResult.Text(QueryJson(SQL_MONITOR_ATTACHMENTS));
  except
    on E: Exception do
      Result := TMCPToolResult.Error(E.Message);
  end;
end;

function TIBMCPStatisticsTools.StatDatabase(const Args: TJsonObject): TMCPToolResult;
begin
  try
    Result := TMCPToolResult.Text(QueryJson(SQL_MONITOR_DATABASE));
  except
    on E: Exception do
      Result := TMCPToolResult.Error(E.Message);
  end;
end;

function TIBMCPStatisticsTools.StatHeaps(const Args: TJsonObject): TMCPToolResult;
begin
  try
    Result := TMCPToolResult.Text(QueryJson(SQL_MONITOR_HEAPS));
  except
    on E: Exception do
      Result := TMCPToolResult.Error(E.Message);
  end;
end;

function TIBMCPStatisticsTools.StatIndices(const Args: TJsonObject): TMCPToolResult;
begin
  try
    Result := TMCPToolResult.Text(QueryJson(SQL_MONITOR_INDICES));
  except
    on E: Exception do
      Result := TMCPToolResult.Error(E.Message);
  end;
end;

function TIBMCPStatisticsTools.StatPoolBlocks(const Args: TJsonObject): TMCPToolResult;
begin
  try
    Result := TMCPToolResult.Text(QueryJson(SQL_MONITOR_POOL_BLOCKS));
  except
    on E: Exception do
      Result := TMCPToolResult.Error(E.Message);
  end;
end;

function TIBMCPStatisticsTools.StatPools(const Args: TJsonObject): TMCPToolResult;
begin
  try
    Result := TMCPToolResult.Text(QueryJson(SQL_MONITOR_POOLS));
  except
    on E: Exception do
      Result := TMCPToolResult.Error(E.Message);
  end;
end;

function TIBMCPStatisticsTools.StatProcedures(const Args: TJsonObject): TMCPToolResult;
begin
  try
    Result := TMCPToolResult.Text(QueryJson(SQL_MONITOR_PROCEDURES));
  except
    on E: Exception do
      Result := TMCPToolResult.Error(E.Message);
  end;
end;

function TIBMCPStatisticsTools.StatRelations(const Args: TJsonObject): TMCPToolResult;
begin
  try
    Result := TMCPToolResult.Text(QueryJson(SQL_MONITOR_RELATIONS));
  except
    on E: Exception do
      Result := TMCPToolResult.Error(E.Message);
  end;
end;

function TIBMCPStatisticsTools.StatStatements(const Args: TJsonObject): TMCPToolResult;
begin
  try
    Result := TMCPToolResult.Text(QueryJson(SQL_MONITOR_STATEMENTS));
  except
    on E: Exception do
      Result := TMCPToolResult.Error(E.Message);
  end;
end;

function TIBMCPStatisticsTools.StatTransactions(const Args: TJsonObject): TMCPToolResult;
begin
  try
    Result := TMCPToolResult.Text(QueryJson(SQL_MONITOR_TRANSACTIONS));
  except
    on E: Exception do
      Result := TMCPToolResult.Error(E.Message);
  end;
end;

function TIBMCPStatisticsTools.StatTriggers(const Args: TJsonObject): TMCPToolResult;
begin
  try
    Result := TMCPToolResult.Text(QueryJson(SQL_MONITOR_TRIGGERS));
  except
    on E: Exception do
      Result := TMCPToolResult.Error(E.Message);
  end;
end;

end.
