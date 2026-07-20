unit IB.MCP.ConnectionManager;

interface

uses
  FireDAC.Comp.Client;

type
  /// <summary>
  /// Factory for InterBase FireDAC connections.
  /// </summary>
  TIBMCPConnectionManager = class
  private
    class var FInitialized: Boolean;
    class var FLock: TObject;

    class constructor CreateClass;
    class destructor DestroyClass;
    class procedure ConfigureConnection(AConnection: TFDConnection); static;
    class procedure ConfigureConnectionDef; static;
  public
    /// <summary>Returns the configured FireDAC connection definition name.</summary>
    class function ConnectionDefName: string; static;

    /// <summary>Configures the FDManager connection definition once.</summary>
    class procedure Initialize; static;

    /// <summary>Creates and opens a caller-owned connection.</summary>
    class function CreateConnection: TFDConnection; static;

    /// <summary>Opens and closes a test connection to validate startup configuration.</summary>
    class procedure ValidateConnection; static;
  end;

implementation

uses
  System.Classes,
  System.SysUtils,
  FireDAC.Stan.Def,
  FireDAC.Phys,
  FireDAC.Phys.IB,
  FireDAC.DApt,
  IB.MCP.Settings;

const
  CConnectionDefName = 'IB_MCP_CONNECTION';

  { TIBMCPConnectionManager }

  class constructor TIBMCPConnectionManager.CreateClass;
begin
  inherited;
  FLock := TObject.Create;
end;

class destructor TIBMCPConnectionManager.DestroyClass;
begin
  FLock.Free;
end;

class procedure TIBMCPConnectionManager.ConfigureConnection(AConnection: TFDConnection);
begin
  Initialize;
  AConnection.LoginPrompt := False;
  AConnection.FormatOptions.StrsTrim := True;
  AConnection.ConnectionDefName := ConnectionDefName;
end;

class procedure TIBMCPConnectionManager.ConfigureConnectionDef;
var
  LParams: TStringList;
  LSettings: TIBMCPSettings;
begin
  LSettings := TIBMCPSettings.Create;
  try
    LParams := TStringList.Create;
    try
      LParams.Values['Server'] := LSettings.Host;
      LParams.Values['Port'] := LSettings.Port.ToString;
      LParams.Values['Database'] := LSettings.Database;
      LParams.Values['User_Name'] := LSettings.UserName;
      LParams.Values['Password'] := LSettings.Password;
      LParams.Values['CharacterSet'] := LSettings.CharacterSet;
      LParams.Values['Pooled'] := 'True';
      FDManager.Active := True;
      FDManager.AddConnectionDef(ConnectionDefName, 'IB', LParams, False);
    finally
      LParams.Free;
    end;
  finally
    LSettings.Free;
  end;
end;

class function TIBMCPConnectionManager.ConnectionDefName: string;
begin
  Result := CConnectionDefName;
end;

class function TIBMCPConnectionManager.CreateConnection: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  try
    ConfigureConnection(Result);
    Result.Connected := True;
  except
    Result.Free;
    raise;
  end;
end;

class procedure TIBMCPConnectionManager.Initialize;
begin
  TMonitor.Enter(FLock);
  try
    if FInitialized then
      Exit;

    ConfigureConnectionDef;
    FInitialized := True;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class procedure TIBMCPConnectionManager.ValidateConnection;
var
  LConnection: TFDConnection;
begin
  LConnection := CreateConnection;
  try
    // Opening the connection validates the FDManager definition and credentials.
  finally
    LConnection.Free;
  end;
end;

end.

