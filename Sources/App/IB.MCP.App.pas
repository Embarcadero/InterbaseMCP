unit IB.MCP.App;

interface

type
  /// <summary>
  /// Application entry point for the InterBase MCP server.
  /// </summary>
  TIBMCPApp = class
  public
    /// <summary>
    /// Starts the MCP server and blocks until it is stopped.
    /// </summary>
    class procedure Run; static;
  end;

implementation

uses
  System.Classes,
  System.SysUtils,
  Dext.AI.MCP.Server,
  IB.ConnectionManager,
  IB.Tools.Query,
  IB.Tools.Schema,
  IB.Tools.Performance,
  IB.Tools.Security;

  { TIBMCPApp }

  class procedure TIBMCPApp.Run;
var
  Server: TMCPServer;
begin
  TIBConnectionManager.Initialize;
  TIBConnectionManager.ValidateConnection;

  Server := TMCPServer.Create('mcp-interbase', '0.1.0');
  try
    Server.RegisterProvider(TIBQueryTools.Create);
    Server.RegisterProvider(TIBSchemaTools.Create);
    Server.RegisterProvider(TIBStatisticsTools.Create);
    Server.RegisterProvider(TIBSecurityTools.Create);
    Server.Run(mtStreamable, 'http://localhost:5000');
    Writeln('mcp-interbase listening at http://localhost:5000/mcp');
    Writeln('Press ENTER to stop the process and shut down the server.');
    ReadLn;
  finally
    Server.Stop;
    Server.Free;
  end;
end;

end.

