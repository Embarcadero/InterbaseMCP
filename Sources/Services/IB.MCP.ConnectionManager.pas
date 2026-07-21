unit IB.MCP.ConnectionManager;

interface

uses
  FireDAC.Comp.Client,
  ib.MCP.Settings;

type
  /// <summary>
  /// Factory for InterBase FireDAC connections.
  /// </summary>
  TIBMCPConnectionManager = class
  private
    class var FInitialized: Boolean;
    class var FLock: TObject;
    FSettings: TIBMCPSettings;

    class constructor CreateClass;
    class destructor DestroyClass;
    class procedure ConfigureConnection(AConnection: TFDConnection); static;
    procedure ConfigureConnectionDef;
  public
    constructor Create(const ASettings: TIBMCPSettings);
    destructor Destroy; override;

    /// <summary>Returns the configured FireDAC connection definition name.</summary>
    class function ConnectionDefName: string; static;

    /// <summary>Configures the FDManager connection definition once.</summary>
    procedure Initialize;

    /// <summary>Creates and opens a caller-owned connection.</summary>
    function CreateConnection: TFDConnection;

    /// <summary>Opens and closes a test connection to validate startup configuration.</summary>
    procedure ValidateConnection;
  end;

implementation

uses
  System.Classes,
  System.SysUtils,
  FireDAC.Stan.Def,
  FireDAC.Phys,
  FireDAC.Phys.IB,
  FireDAC.DApt;

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
  AConnection.LoginPrompt := False;
  AConnection.FormatOptions.StrsTrim := True;
  AConnection.ConnectionDefName := ConnectionDefName;
end;

constructor TIBMCPConnectionManager.Create(const ASettings: TIBMCPSettings);
begin
  inherited Create;
  FSettings := ASettings;
end;

destructor TIBMCPConnectionManager.Destroy;
begin
  inherited Destroy;
end;

procedure TIBMCPConnectionManager.ConfigureConnectionDef;
var
  LParams: TStringList;
begin
  LParams := TStringList.Create;
  try
    LParams.Values['Server'] := FSettings.Host;
    LParams.Values['Port'] := FSettings.Port.ToString;
    LParams.Values['Database'] := FSettings.Database;
    LParams.Values['User_Name'] := FSettings.UserName;
    LParams.Values['Password'] := FSettings.Password;
    LParams.Values['CharacterSet'] := FSettings.CharacterSet;
    LParams.Values['Pooled'] := 'True';
    FDManager.Active := True;
    FDManager.AddConnectionDef(ConnectionDefName, 'IB', LParams, False);
  finally
    LParams.Free;
  end;
end;

class function TIBMCPConnectionManager.ConnectionDefName: string;
begin
  Result := CConnectionDefName;
end;

procedure TIBMCPConnectionManager.Initialize;
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

function TIBMCPConnectionManager.CreateConnection: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  try
    ConfigureConnection(Result);
    Initialize;
    Result.Connected := True;
  except
    Result.Free;
    raise;
  end;
end;

procedure TIBMCPConnectionManager.ValidateConnection;
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
