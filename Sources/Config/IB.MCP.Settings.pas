unit IB.MCP.Settings;

interface

type
  /// <summary>
  /// Loads and exposes server settings from mcp_interbase.ini.
  /// </summary>
  TIBMCPSettings = class
  private
    FHost: string;
    FPort: Integer;
    FDatabase: string;
    FUserName: string;
    FPassword: string;
    FCharacterSet: string;
    FPoolSize: Integer;
    FPoolMinSize: Integer;
    FPoolMaxSize: Integer;
    FAllowWrites: Boolean;
    FSSL: Boolean;
    FDangerousKeywords: string;
    FAuditPath: string;
  public
    constructor Create;

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
    /// <summary>Default pool size.</summary>
    property PoolSize: Integer read FPoolSize write FPoolSize;
    /// <summary>Minimum pool size.</summary>
    property PoolMinSize: Integer read FPoolMinSize write FPoolMinSize;
    /// <summary>Maximum pool size.</summary>
    property PoolMaxSize: Integer read FPoolMaxSize write FPoolMaxSize;
    /// <summary>Allows write statements.</summary>
    property AllowWrites: Boolean read FAllowWrites write FAllowWrites;
    /// <summary>Uses SSL for the connection.</summary>
    property SSL: Boolean read FSSL write FSSL;
    /// <summary>Blocked SQL keywords.</summary>
    property DangerousKeywords: string read FDangerousKeywords write FDangerousKeywords;
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
    // [Database]
    FHost := LIniFile.ReadString('Database', 'Host', 'localhost');
    FPort := LIniFile.ReadInteger('Database', 'Port', 3050);
    FDatabase := LIniFile.ReadString('Database', 'Database', 'c:\data\employee.gdb');
    FUserName := LIniFile.ReadString('Database', 'UserName', 'SYSDBA');
    FPassword := LIniFile.ReadString('Database', 'Password', 'masterkey');
    FCharacterSet := LIniFile.ReadString('Database', 'CharacterSet', 'UTF8');

    // [Pool]
    FPoolSize := LIniFile.ReadInteger('Pool', 'PoolSize', 5);
    FPoolMinSize := LIniFile.ReadInteger('Pool', 'PoolMinSize', 1);
    FPoolMaxSize := LIniFile.ReadInteger('Pool', 'PoolMaxSize', 10);

    // [Security]
    FAllowWrites := LIniFile.ReadBool('Security', 'AllowWrites', False);
    FSSL := LIniFile.ReadBool('Security', 'SSL', False);
    FDangerousKeywords :=
    LIniFile.ReadString('Security', 'DangerousKeywords', 'DROP,TRUNCATE,GRANT,REVOKE,ALTER USER,CREATE USER');

    // [Logging]
    FAuditPath := LIniFile.ReadString('Logging', 'AuditPath', 'logs/audit.jsonl');
  finally
    LIniFile.Free;
  end;
end;

end.

