program mcp_interbase;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  IB.MCP.App in 'Sources\App\IB.MCP.App.pas',
  IB.MCP.Settings in 'Sources\Config\IB.MCP.Settings.pas',
  IB.SqlValidator in 'Sources\Services\IB.SqlValidator.pas',
  IB.AuditLogger in 'Sources\Services\IB.AuditLogger.pas',
  IB.DatasetHelper in 'Sources\Services\IB.DatasetHelper.pas',
  IB.Tools.Query in 'Sources\Tools\IB.Tools.Query.pas',
  IB.Tools.Schema in 'Sources\Tools\IB.Tools.Schema.pas',
  IB.Tools.Performance in 'Sources\Tools\IB.Tools.Performance.pas',
  IB.Tools.Security in 'Sources\Tools\IB.Tools.Security.pas',
  IB.ConnectionManager in 'Sources\Services\IB.ConnectionManager.pas';

begin
  TIBMCPApp.Run;
end.
