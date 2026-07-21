unit IB.MCP.App;

interface

uses
  IB.MCP.AuditLogger,
  IB.MCP.ConnectionManager,
  IB.MCP.Settings,
  IB.MCP.SqlValidator;

type
  /// <summary>
  /// Application entry point for the InterBase MCP server.
  /// </summary>
  TIBMCPApp = class
  strict private
    FSettings: TIBMCPSettings;
    FAuditLogger: TIBMCPAuditLogger;
    FConnectionManager: TIBMCPConnectionManager;
    FSqlValidator: TIBMCPSqlValidator;
    FUserLevel: TUserLevel;
    function GetServerUrl: string;
    class var FCurrent: TIBMCPApp;
  public
    constructor Create;
    destructor Destroy; override;

    class function Current: TIBMCPApp; static;

    property Settings: TIBMCPSettings read FSettings;
    property AuditLogger: TIBMCPAuditLogger read FAuditLogger;
    property ConnectionManager: TIBMCPConnectionManager read FConnectionManager;
    property SqlValidator: TIBMCPSqlValidator read FSqlValidator;
    property UserLevel: TUserLevel read FUserLevel write FUserLevel;

    /// <summary>
    /// Starts the MCP server (HTTP or HTTPS depending on UseHttps setting)
    /// and blocks until the user presses ENTER.
    /// </summary>
    class procedure Run; static;
  end;

implementation

uses
  System.SysUtils,
  Dext.AI.MCP.Server,
  Dext.Web.Interfaces,
  Dext.Server.Engine.Types,
  IB.MCP.Query,
  IB.MCP.Schema,
  IB.MCP.Statistics,
  IB.MCP.Security,
  IB.MCP.Management;

constructor TIBMCPApp.Create;
begin
  inherited Create;
  FSettings := TIBMCPSettings.Create;
  FAuditLogger := TIBMCPAuditLogger.Create;
  FConnectionManager := TIBMCPConnectionManager.Create(FSettings);
  FSqlValidator := TIBMCPSqlValidator.Create;
end;

destructor TIBMCPApp.Destroy;
begin
  FSqlValidator.Free;
  FConnectionManager.Free;
  FAuditLogger.Free;
  FSettings.Free;
  inherited Destroy;
end;

class function TIBMCPApp.Current: TIBMCPApp;
begin
  Result := FCurrent;
end;

function TIBMCPApp.GetServerUrl: string;
begin
  if FSettings.UseHttps then
    Result := Format('https://%s:%d', [FSettings.MCPHost, FSettings.MCPPort])
  else
    Result := Format('http://%s:%d', [FSettings.MCPHost, FSettings.MCPPort]);
end;

class procedure TIBMCPApp.Run;
var
  App: TIBMCPApp;
  Server: TMCPServer;
begin
  App := TIBMCPApp.Create;
  FCurrent := App;
  try
    App.ConnectionManager.Initialize;
    App.ConnectionManager.ValidateConnection;

    Server := TMCPServer.Create('mcp-interbase', '0.1.0');
    try
      Server.RegisterProvider(TIBMCPQueryTools.Create);
      Server.RegisterProvider(TIBMCPSchemaTools.Create);
      Server.RegisterProvider(TIBMCPSecurityTools.Create);
      Server.RegisterProvider(TIBMCPStatisticsTools.Create);
      Server.RegisterProvider(TIBMCPManagementTools.Create);

      Server.ConfigureApp(procedure(AppBuilder: IApplicationBuilder)
      begin
        AppBuilder.Use(
        procedure(Context: IHttpContext; Next: TRequestDelegate)
        var
          ProvidedToken: string;
        begin
          ProvidedToken := Context.Request.GetHeader('Authorization');
          App.UserLevel := App.Settings.GetUserLevel(ProvidedToken);
          if App.UserLevel = [] then
          begin
            Context.Response.StatusCode := 401;
            Context.Response.Write('Unauthorized: Invalid Shared Token');
            Exit;
          end;
          Next(Context);
        end);
      end);

      Server.Run(mtStreamable, App.GetServerUrl);

      Writeln(Format('mcp-interbase listening at %s/mcp', [App.GetServerUrl]));
      Writeln('Press ENTER to stop the process and shut down the server.');
      ReadLn;
    finally
      Server.Stop;
      Server.Free;
    end;
  finally
    FCurrent := nil;
    App.Free;
  end;
end;

end.
