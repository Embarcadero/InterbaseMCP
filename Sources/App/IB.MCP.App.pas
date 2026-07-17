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
  Dext.Web.Interfaces,
  Dext.Server.Engine.Types,
  IB.MCP.Settings,
  IB.ConnectionManager,
  IB.Tools.Query,
  IB.Tools.Schema,
  IB.Tools.Performance,
  IB.Tools.Security;

  { TIBMCPApp }

  class procedure TIBMCPApp.Run;
var
  Settings: TIBMCPSettings;
  Server: TMCPServer;
  ServerUrl: string;
begin
  TIBConnectionManager.Initialize;
  TIBConnectionManager.ValidateConnection;

  Settings := TIBMCPSettings.Create;
  try
    ServerUrl := Format('http://%s:%d', [Settings.MCPHost, Settings.MCPPort]);

    Server := TMCPServer.Create('mcp-interbase', '0.1.0');
    try
      Server.RegisterProvider(TIBQueryTools.Create);
      Server.RegisterProvider(TIBSchemaTools.Create);
      Server.RegisterProvider(TIBSecurityTools.Create);
      Server.RegisterProvider(TIBStatisticsTools.Create);

      if not Settings.MCPSecret.IsEmpty then
        Server.ConfigureApp(procedure(App: IApplicationBuilder)
        begin
          App.Use(
          procedure(Context: IHttpContext; Next: TRequestDelegate)
          begin
            var ProvidedToken := Context.Request.GetHeader('Authorization');
            if ProvidedToken <> Settings.MCPSecret then
              begin
                Context.Response.StatusCode := 401; // HTTP 401 Unauthorized
                Context.Response.Write('Unauthorized: Invalid Shared Token');
                Exit;
              end;
            Next(Context);
          end
          );
        end);

      Server.Run(mtStreamable, ServerUrl);

      Writeln(Format('mcp-interbase listening at %s/mcp', [ServerUrl]));
      Writeln('Press ENTER to stop the process and shut down the server.');
      ReadLn;
    finally
      Server.Stop;
      Server.Free;
    end;
  finally
    Settings.Free;
  end;
end;

end.


