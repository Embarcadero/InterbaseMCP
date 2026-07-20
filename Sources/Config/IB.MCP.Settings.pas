unit IB.MCP.Settings;

interface

type
  /// <summary>
  /// Loads and exposes server settings from mcp_interbase.ini.
  /// </summary>
  TIBMCPSettings = class
  private
    // [MCPServer]
    FMCPHost: string;
    FMCPPort: Integer;
    FMCPSecret: string;
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
    // [Pool]
    FPoolMinSize: Integer;
    FPoolMaxSize: Integer;
    // [Security]
    FForbiddenDML: string;
    FForbiddenDDL: string;
    // [Logging]
    FAuditPath: string;
  public
    constructor Create;

    /// <summary>MCP server host.</summary>
    property MCPHost: string read FMCPHost write FMCPHost;
    /// <summary>MCP server port.</summary>
    property MCPPort: Integer read FMCPPort write FMCPPort;
    /// <summary>MCP server shared secret.</summary>
    property MCPSecret: string read FMCPSecret write FMCPSecret;
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

    /// <summary>Minimum connection pool size.</summary>
    property PoolMinSize: Integer read FPoolMinSize write FPoolMinSize;
    /// <summary>Maximum connection pool size.</summary>
    property PoolMaxSize: Integer read FPoolMaxSize write FPoolMaxSize;

    /// <summary>Comma-separated DML statements forbidden for execution (e.g. INSERT,UPDATE,DELETE).</summary>
    property ForbiddenDML: string read FForbiddenDML write FForbiddenDML;
    /// <summary>Comma-separated DDL statements forbidden for execution (e.g. CREATE,ALTER,DROP).</summary>
    property ForbiddenDDL: string read FForbiddenDDL write FForbiddenDDL;

    /// <summary>Audit log path.</summary>
    property AuditPath: string read FAuditPath write FAuditPath;
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
    FMCPHost      := LIniFile.ReadString ('MCPServer', 'MCPHost',      'localhost');
    FMCPPort      := LIniFile.ReadInteger('MCPServer', 'MCPPort',      5000);
    FMCPSecret    := LIniFile.ReadString ('MCPServer', 'MCPSecret',    '');
    FUseHttps     := LIniFile.ReadBool   ('MCPServer', 'UseHttps',     False);
    FSslProvider  := LIniFile.ReadString ('MCPServer', 'SslProvider',  'OpenSSL');
    FSslCert      := LIniFile.ReadString ('MCPServer', 'SslCert',      'server.crt');
    FSslKey       := LIniFile.ReadString ('MCPServer', 'SslKey',       'server.key');
    FSslRootCert  := LIniFile.ReadString ('MCPServer', 'SslRootCert',  '');

    // [Database]
    FHost         := LIniFile.ReadString ('Database', 'Host',         'localhost');
    FPort         := LIniFile.ReadInteger('Database', 'Port',         3050);
    FDatabase     := LIniFile.ReadString ('Database', 'Database',     'c:\data\employee.gdb');
    FUserName     := LIniFile.ReadString ('Database', 'UserName',     'SYSDBA');
    FPassword     := LIniFile.ReadString ('Database', 'Password',     'masterkey');
    FCharacterSet := LIniFile.ReadString ('Database', 'CharacterSet', 'UTF8');

    // [Pool]
    FPoolMinSize  := LIniFile.ReadInteger('Pool', 'PoolMinSize', 1);
    FPoolMaxSize  := LIniFile.ReadInteger('Pool', 'PoolMaxSize', 10);

    // [Security]
    FForbiddenDML := LIniFile.ReadString('Security', 'ForbiddenDML', 'INSERT,UPDATE,DELETE,TRUNCATE');
    FForbiddenDDL := LIniFile.ReadString('Security', 'ForbiddenDDL', 'CREATE,ALTER,DROP,GRANT,REVOKE,SET');

    // [Logging]
    FAuditPath := LIniFile.ReadString('Logging', 'AuditPath', 'logs/audit.jsonl');
  finally
    LIniFile.Free;
  end;
end;

end.
