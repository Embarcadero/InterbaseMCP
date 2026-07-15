unit IB.MCP.App;

interface

type
  /// <summary>
  /// Main application class for the Interbase MCP server.
  /// </summary>
  TIBMCPApp = class
  public
    /// <summary>
    /// Initializes and runs the MCP server, blocking the current thread until the server is shut down.
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
  Server := TMCPServer.Create('mcp-interbase', '0.1.0');
  try
    Server.RegisterProvider(TIBQueryTools.Create);
    Server.RegisterProvider(TIBSchemaTools.Create);
    Server.RegisterProvider(TIBStatisticsTools.Create);
    Server.RegisterProvider(TIBSecurityTools.Create);
    Server.Run(mtStreamable, 'http://localhost:5000');
    Writeln('mcp-interbase listening at http://localhost:5000/mcp');
    Writeln('Stop the process to shut down the server.');
    while True do
      TThread.Sleep(1000);
  finally
    Server.Stop;
    Server.Free;
  end;
end;

end.
