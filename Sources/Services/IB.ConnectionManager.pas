unit IB.ConnectionManager;

interface

uses
  FireDAC.Comp.Client;

type
  /// <summary>
  /// Factory for InterBase FireDAC connections.
  /// </summary>
  TIBConnectionManager = class
  private
    class var FInitialized: Boolean;
    class var FLock: TObject;

    class constructor CreateClass;
    class destructor DestroyClass;
    class function EffectivePoolMaximum(const APoolSize, APoolMaxSize: Integer): Integer; static;
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

  { TIBConnectionManager }

  class constructor TIBConnectionManager.CreateClass;
begin
  inherited;
  FLock := TObject.Create;
end;

class destructor TIBConnectionManager.DestroyClass;
begin
  FLock.Free;
end;

class procedure TIBConnectionManager.ConfigureConnection(AConnection: TFDConnection);
begin
  Initialize;
  AConnection.LoginPrompt := False;
  AConnection.FormatOptions.StrsTrim := True;
  AConnection.ConnectionDefName := ConnectionDefName;
end;

class procedure TIBConnectionManager.ConfigureConnectionDef;
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
      LParams.Values['POOL_MaximumItems'] := EffectivePoolMaximum(LSettings.PoolSize, LSettings.PoolMaxSize).ToString;
      LParams.Values['SSL'] := if LSettings.SSL then 'True' else 'False';
      LParams.Values['ReadOnly'] := if LSettings.AllowWrites then 'False' else 'True';

      FDManager.Active := True;
      FDManager.AddConnectionDef(ConnectionDefName, 'IB', LParams, False);
    finally
      LParams.Free;
    end;
  finally
    LSettings.Free;
  end;
end;

class function TIBConnectionManager.ConnectionDefName: string;
begin
  Result := CConnectionDefName;
end;

class function TIBConnectionManager.CreateConnection: TFDConnection;
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

class function TIBConnectionManager.EffectivePoolMaximum(const APoolSize, APoolMaxSize: Integer): Integer;
begin
  Result := APoolMaxSize;
  if Result <= 0 then
    Result := APoolSize;
  if Result <= 0 then
    Result := 10;
end;

class procedure TIBConnectionManager.Initialize;
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

class procedure TIBConnectionManager.ValidateConnection;
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

