program mcp_interbase;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  IB.MCP.App in 'Sources\App\IB.MCP.App.pas',
  IB.MCP.Settings in 'Sources\Config\IB.MCP.Settings.pas',
  IB.MCP.SqlValidator in 'Sources\Services\IB.MCP.SqlValidator.pas',
  IB.MCP.AuditLogger in 'Sources\Services\IB.MCP.AuditLogger.pas',
  IB.MCP.DatasetHelper in 'Sources\Services\IB.MCP.DatasetHelper.pas',
  IB.MCP.Query in 'Sources\Tools\IB.MCP.Query.pas',
  IB.MCP.Schema in 'Sources\Tools\IB.MCP.Schema.pas',
  IB.MCP.Statistics in 'Sources\Tools\IB.MCP.Statistics.pas',
  IB.MCP.Security in 'Sources\Tools\IB.MCP.Security.pas',
  IB.MCP.ConnectionManager in 'Sources\Services\IB.MCP.ConnectionManager.pas',
  IB.MCP.Management in 'Sources\Tools\IB.MCP.Management.pas';

begin
  TIBMCPApp.Run;
end.
