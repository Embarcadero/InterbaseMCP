unit IB.MCP.Settings;

interface

type
  /// <summary>
  /// Manages configuration settings for the Interbase MCP Server, loaded from mcp_interbase.ini.
  /// </summary>
  TIBSettings = class
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
    FLogToConsole: Boolean;
  public
    /// <summary>
    /// Initializes settings by reading the configuration file.
    /// </summary>
    constructor Create;

    /// <summary>Database host address.</summary>
    property Host: string read FHost write FHost;
    /// <summary>Database connection port.</summary>
    property Port: Integer read FPort write FPort;
    /// <summary>Database file path or alias.</summary>
    property Database: string read FDatabase write FDatabase;
    /// <summary>Database authentication username.</summary>
    property UserName: string read FUserName write FUserName;
    /// <summary>Database authentication password.</summary>
    property Password: string read FPassword write FPassword;
    /// <summary>Character set for the connection.</summary>
    property CharacterSet: string read FCharacterSet write FCharacterSet;
    /// <summary>Default connection pool size.</summary>
    property PoolSize: Integer read FPoolSize write FPoolSize;
    /// <summary>Minimum connection pool size.</summary>
    property PoolMinSize: Integer read FPoolMinSize write FPoolMinSize;
    /// <summary>Maximum connection pool size.</summary>
    property PoolMaxSize: Integer read FPoolMaxSize write FPoolMaxSize;
    /// <summary>Indicates if write operations (INSERT, UPDATE, DELETE) are allowed.</summary>
    property AllowWrites: Boolean read FAllowWrites write FAllowWrites;
    /// <summary>Indicates if the connection requires SSL.</summary>
    property SSL: Boolean read FSSL write FSSL;
    /// <summary>Comma-separated list of dangerous SQL keywords to block.</summary>
    property DangerousKeywords: string read FDangerousKeywords write FDangerousKeywords;
    /// <summary>File path for the audit log.</summary>
    property AuditPath: string read FAuditPath write FAuditPath;
    /// <summary>Indicates if audit events should be logged to the console.</summary>
    property LogToConsole: Boolean read FLogToConsole write FLogToConsole;
  end;

implementation

uses
  System.SysUtils,
  System.IniFiles;

{ TIBSettings }

constructor TIBSettings.Create;
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
    FLogToConsole := LIniFile.ReadBool('Logging', 'LogToConsole', True);
  finally
    LIniFile.Free;
  end;
end;

end.
