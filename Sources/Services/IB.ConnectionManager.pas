unit IB.ConnectionManager;

interface

uses
  FireDAC.Comp.Client,
  Dext.Options,
  IB.MCP.Settings;

type
  /// <summary>
  /// Manages FireDAC database connections to Interbase using a singleton pattern and connection pooling.
  /// </summary>
  TIBConnectionManager = class
  private
    class var FInstance: TIBConnectionManager;
    class var FLock: TObject;

    FConnection: TFDConnection;
    FConnectionDefName: string;
    FSettings: TIBSettings;
    FOwnsSettings: Boolean;

    class constructor CreateClass;
    class destructor DestroyClass;
    function EffectivePoolMaximum: Integer;
    procedure ConfigureConnectionDef;
    procedure EnsureConnectionDef;
  public
    /// <summary>
    /// Initializes a new connection manager instance.
    /// </summary>
    constructor Create; overload;
    
    /// <summary>
    /// Destroys the connection manager and releases active connections.
    /// </summary>
    destructor Destroy; override;

    /// <summary>
    /// Returns the singleton instance of the connection manager.
    /// </summary>
    /// <returns>TIBConnectionManager instance.</returns>
    class function Instance: TIBConnectionManager; static;
    
    /// <summary>
    /// Retrieves an active FireDAC connection, acquiring it from the pool if necessary.
    /// </summary>
    /// <returns>An active TFDConnection.</returns>
    function Connection: TFDConnection;
    
    /// <summary>
    /// Closes and releases the active connection and removes the connection definition.
    /// </summary>
    procedure Close;
  end;

implementation

uses
  System.Classes,
  System.SysUtils,
  FireDAC.Stan.Def,
  FireDAC.Phys,
  FireDAC.Phys.IB,
  FireDAC.DApt;

{ TIBConnectionManager }

class constructor TIBConnectionManager.CreateClass;
begin
  inherited;
  FLock := TObject.Create;
end;

class destructor TIBConnectionManager.DestroyClass;
begin
  FInstance.Free;
  FLock.Free;
end;

constructor TIBConnectionManager.Create;
begin
  inherited Create;
  FSettings := TIBSettings.Create;
  FOwnsSettings := True;
  ConfigureConnectionDef;
end;

destructor TIBConnectionManager.Destroy;
begin
  Close;
  if FOwnsSettings then
    FSettings.Free;
  inherited Destroy;
end;

class function TIBConnectionManager.Instance: TIBConnectionManager;
begin
  TMonitor.Enter(FLock);
  try
    if not Assigned(FInstance) then
      FInstance := TIBConnectionManager.Create;
    Result := FInstance;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TIBConnectionManager.Connection: TFDConnection;
begin
  TMonitor.Enter(FLock);
  try
    EnsureConnectionDef;
    if not Assigned(FConnection) then
    begin
      FConnection := TFDConnection.Create(nil);
      FConnection.LoginPrompt := False;
      FConnection.FormatOptions.StrsTrim := True;
      FConnection.ConnectionDefName := FConnectionDefName;
    end;

    if not FConnection.Connected then
      FConnection.Connected := True;

    Result := FConnection;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TIBConnectionManager.Close;
begin
  TMonitor.Enter(FLock);
  try
    FreeAndNil(FConnection);

    if FConnectionDefName = '' then
      Exit;

    FDManager.CloseConnectionDef(FConnectionDefName);
    FDManager.DeleteConnectionDef(FConnectionDefName);
    FConnectionDefName := '';
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TIBConnectionManager.ConfigureConnectionDef;
var
  Params: TStringList;
begin
  FConnectionDefName := 'IB_MCP_CONNECTION';
  Params := TStringList.Create;
  try
    Params.Values['Server'] := FSettings.Host;
    Params.Values['Port'] := FSettings.Port.ToString;
    Params.Values['Database'] := FSettings.Database;
    Params.Values['User_Name'] := FSettings.UserName;
    Params.Values['Password'] := FSettings.Password;
    Params.Values['CharacterSet'] := FSettings.CharacterSet;
    Params.Values['Pooled'] := 'True';
    Params.Values['POOL_MaximumItems'] := EffectivePoolMaximum.ToString;
    Params.Values['SSL'] := if FSettings.SSL then 'True' else 'False';
    Params.Values['ReadOnly'] := if FSettings.AllowWrites then 'True' else 'False';
    FDManager.Active := True;
    FDManager.AddConnectionDef(FConnectionDefName, 'IB', Params, False);
  finally
    Params.Free;
  end;
end;

procedure TIBConnectionManager.EnsureConnectionDef;
begin
  if FConnectionDefName = '' then
    ConfigureConnectionDef;
end;

function TIBConnectionManager.EffectivePoolMaximum: Integer;
begin
  Result := FSettings.PoolMaxSize;
  if Result <= 0 then
    Result := FSettings.PoolSize;
  if Result <= 0 then
    Result := 10;
end;

end.
