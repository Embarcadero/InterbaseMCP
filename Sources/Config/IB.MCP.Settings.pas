unit IB.MCP.Settings;

interface

type
  TUserRight = (urView, urCrud, urDba);
  TUserLevel = set of TUserRight;

  /// <summary>
  /// Loads and exposes server settings from mcp_interbase.ini.
  /// </summary>
  TIBMCPSettings = class
  private
    // [MCPServer]
    FMCPHost: string;
    FMCPPort: Integer;
    FUseHttps: Boolean;
    FSslProvider: string;
    FSslCert: string;
    FSslKey: string;
    FSslRootCert: string;
    // [Database]
    FHost: string;
    FPort: Integer;
    FDatabase: string;
    FUserName: string;
    FPassword: string;
    FCharacterSet: string;
    // [Security]
    FForbiddenDML: string;
    FForbiddenDDL: string;
    FVIEWSecret: string;
    FCRUDSecret: string;
    FDBASecret: string;
    // [Logging]
    FAuditPath: string;
  public
    constructor Create;

    /// <summary>MCP server host.</summary>
    property MCPHost: string read FMCPHost write FMCPHost;
    /// <summary>MCP server port.</summary>
    property MCPPort: Integer read FMCPPort write FMCPPort;
    /// <summary>Enables HTTPS for the MCP server endpoint.</summary>
    property UseHttps: Boolean read FUseHttps write FUseHttps;
    /// <summary>SSL/TLS provider name (e.g. OpenSSL).</summary>
    property SslProvider: string read FSslProvider write FSslProvider;
    /// <summary>Path to the SSL certificate file.</summary>
    property SslCert: string read FSslCert write FSslCert;
    /// <summary>Path to the SSL private key file.</summary>
    property SslKey: string read FSslKey write FSslKey;
    /// <summary>Path to the SSL root/CA certificate file.</summary>
    property SslRootCert: string read FSslRootCert write FSslRootCert;

    /// <summary>Database host.</summary>
    property Host: string read FHost write FHost;
    /// <summary>Database port.</summary>
    property Port: Integer read FPort write FPort;
    /// <summary>Database path or alias.</summary>
    property Database: string read FDatabase write FDatabase;
    /// <summary>Database user name.</summary>
    property UserName: string read FUserName write FUserName;
    /// <summary>Database password.</summary>
    property Password: string read FPassword write FPassword;
    /// <summary>Connection character set.</summary>
    property CharacterSet: string read FCharacterSet write FCharacterSet;

    /// <summary>Comma-separated DML statements forbidden for execution (e.g. INSERT,UPDATE,DELETE).</summary>
    property ForbiddenDML: string read FForbiddenDML write FForbiddenDML;
    /// <summary>Comma-separated DDL statements forbidden for execution (e.g. CREATE,ALTER,DROP).</summary>
    property ForbiddenDDL: string read FForbiddenDDL write FForbiddenDDL;
    /// <summary>Shared secret for VIEW-level (read-only) tool access.</summary>
    property VIEWSecret: string read FVIEWSecret write FVIEWSecret;
    /// <summary>Shared secret for CRUD-level tool access.</summary>
    property CRUDSecret: string read FCRUDSecret write FCRUDSecret;
    /// <summary>Shared secret for DBA-level tool access.</summary>
    property DBASecret: string read FDBASecret write FDBASecret;

    /// <summary>Audit log path.</summary>
    property AuditPath: string read FAuditPath write FAuditPath;

    /// <summary>Compute user level based on Authorization header and configured secrets.</summary>
    function GetUserLevel(const AuthorizationHeader: string): TUserLevel;
  end;

implementation

uses
  System.SysUtils,
  System.IniFiles;

{ TIBMCPSettings }

constructor TIBMCPSettings.Create;
var
  LIniFile: TIniFile;
  LIniPath: string;
begin
  inherited Create;

  LIniPath := ExtractFilePath(ParamStr(0)) + 'mcp_interbase.ini';
  LIniFile := TIniFile.Create(LIniPath);
  try
    // [MCPServer]
    FMCPHost      := LIniFile.ReadString ('MCPServer', 'MCPHost',     'localhost');
    FMCPPort      := LIniFile.ReadInteger('MCPServer', 'MCPPort',     5000);
    FUseHttps     := LIniFile.ReadBool   ('MCPServer', 'UseHttps',    False);
    FSslProvider  := LIniFile.ReadString ('MCPServer', 'SslProvider', 'OpenSSL');
    FSslCert      := LIniFile.ReadString ('MCPServer', 'SslCert',     '');
    FSslKey       := LIniFile.ReadString ('MCPServer', 'SslKey',      '');
    FSslRootCert  := LIniFile.ReadString ('MCPServer', 'SslRootCert', '');

    // [Database]
    FHost         := LIniFile.ReadString ('Database', 'Host',         'localhost');
    FPort         := LIniFile.ReadInteger('Database', 'Port',         3050);
    FDatabase     := LIniFile.ReadString ('Database', 'Database',     'c:\data\employee.gdb');
    FUserName     := LIniFile.ReadString ('Database', 'UserName',     'SYSDBA');
    FPassword     := LIniFile.ReadString ('Database', 'Password',     'masterkey');
    FCharacterSet := LIniFile.ReadString ('Database', 'CharacterSet', 'UTF8');

    // [Security]
    FForbiddenDML := LIniFile.ReadString('Security', 'ForbiddenDML', 'INSERT,UPDATE,DELETE,TRUNCATE');
    FForbiddenDDL := LIniFile.ReadString('Security', 'ForbiddenDDL', 'CREATE,ALTER,DROP,GRANT,REVOKE,SET');
    FVIEWSecret   := LIniFile.ReadString('Security', 'VIEWSecret',   '');
    FCRUDSecret   := LIniFile.ReadString('Security', 'CRUDSecret',   '');
    FDBASecret    := LIniFile.ReadString('Security', 'DBASecret',    '');

    // [Logging]
    FAuditPath := LIniFile.ReadString('Logging', 'AuditPath', 'logs/audit.jsonl');
  finally
    LIniFile.Free;
  end;
end;

function TIBMCPSettings.GetUserLevel(const AuthorizationHeader: string): TUserLevel;
begin
  Result := [];
  // empty secret means "open" access for that level
  if (FVIEWSecret = '') or (AuthorizationHeader = FVIEWSecret) then
    Include(Result, urView);
  if (FCRUDSecret = '') or (AuthorizationHeader = FCRUDSecret) then
   begin
    Include(Result, urView);
    Include(Result, urCrud);
   end;
  if (FDBASecret = '') or (AuthorizationHeader = FDBASecret) then
   begin
    Include(Result, urView);
    Include(Result, urCrud);
    Include(Result, urDba);
   end;
end;

end.
