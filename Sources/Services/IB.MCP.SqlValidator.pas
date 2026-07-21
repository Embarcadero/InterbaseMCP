unit IB.MCP.SqlValidator;

interface

uses
  System.Generics.Collections,
  Dext.Options,
  IB.MCP.Settings;

type
  /// <summary>
  /// Outcome of a SQL validation check. <c>Accepted</c> is True when the
  /// statement passed all rules; <c>Reason</c> carries a human-readable
  /// rejection message when <c>Accepted</c> is False, or an informational
  /// message when True.
  /// </summary>
  TIBMCPSqlValidationResult = record
    /// <summary>True when the statement is permitted to execute.</summary>
    Accepted: Boolean;
    /// <summary>Rejection reason (when Accepted = False) or informational note (when True).</summary>
    Reason: string;
    /// <summary>Returns an accepted result with an optional informational reason.</summary>
    class function Allow(const AReason: string = ''): TIBMCPSqlValidationResult; static;
    /// <summary>Returns a rejected result with a mandatory rejection reason.</summary>
    class function Reject(const AReason: string): TIBMCPSqlValidationResult; static;
  end;

  /// <summary>
  /// Validates SQL against configured safety rules.
  /// </summary>
  TIBMCPSqlValidator = class
  private
    FSettings: TIBMCPSettings;
    FOwnsSettings: Boolean;
    FEmaByTool: TDictionary<string, Double>;

    /// <summary>Returns True when ASql contains a keyword forbidden by ForbiddenDML or ForbiddenDDL settings.</summary>
    function HasForbiddenKeyword(const ASql: string; out AKeyword: string): Boolean;
  public
    /// <summary>Creates the validator, loading settings from mcp_interbase.ini.</summary>
    constructor Create; overload;
    destructor Destroy; override;

    /// <summary>
    /// Returns True when the SQL statement produces a result-set cursor (SELECT).
    /// </summary>
    function ReturnsCursor(const ASql: string): Boolean;

    /// <summary>True when the SQL is a VIEW-level statement (SELECT).</summary>
    function IsViewStatement(const ASql: string): Boolean;
    /// <summary>True when the SQL is a CRUD-level statement (INSERT,UPDATE,DELETE,TRUNCATE).</summary>
    function IsCrudStatement(const ASql: string): Boolean;
    /// <summary>True when the SQL is a DBA-level statement (CREATE,ALTER,DROP,GRANT,REVOKE,SET).</summary>
    function IsDbaStatement(const ASql: string): Boolean;

    /// <summary>
    /// Validates a SQL statement against the configured ForbiddenDML and
    /// ForbiddenDDL keyword lists.
    /// </summary>
    /// <param name="ASql">SQL text to validate.</param>
    /// <returns>Validation outcome with Accepted = True when the statement is permitted.</returns>
    function ValidateSql(const ASql: string): TIBMCPSqlValidationResult;
  end;

implementation

uses
  System.StrUtils,
  System.SysUtils;

  { TIBMCPSqlValidationResult }

  class function TIBMCPSqlValidationResult.Allow(const AReason: string): TIBMCPSqlValidationResult;
begin
  Result.Accepted := True;
  Result.Reason := AReason;
end;

class function TIBMCPSqlValidationResult.Reject(const AReason: string): TIBMCPSqlValidationResult;
begin
  Result.Accepted := False;
  Result.Reason := AReason;
end;

{ TIBMCPSqlValidator }

constructor TIBMCPSqlValidator.Create;
begin
  inherited Create;
  FSettings := TIBMCPSettings.Create;
  FOwnsSettings := True;
  FEmaByTool := TDictionary<string, Double>.Create;
end;

destructor TIBMCPSqlValidator.Destroy;
begin
  FEmaByTool.Free;
  if FOwnsSettings then
    FSettings.Free;
  inherited Destroy;
end;

function TIBMCPSqlValidator.HasForbiddenKeyword(const ASql: string; out AKeyword: string): Boolean;
var
  AllForbidden: string;
  Keywords: TArray<string>;
  Keyword: string;
  NormalizedKeyword: string;
  NormalizedSql: string;
begin
  Result := False;
  AKeyword := '';
  NormalizedSql := ' ' + ASql.ToUpperInvariant + ' ';
  AllForbidden := FSettings.ForbiddenDML + ',' + FSettings.ForbiddenDDL;
  Keywords := AllForbidden.Split([',']);
  for Keyword in Keywords do begin
    NormalizedKeyword := Trim(Keyword).ToUpperInvariant;
    if NormalizedKeyword = '' then
      Continue;

    if ContainsText(NormalizedSql, NormalizedKeyword) then begin
      AKeyword := NormalizedKeyword;
      Exit(True);
    end;
  end;
end;

function TIBMCPSqlValidator.IsViewStatement(const ASql: string): Boolean;
var
  Sql: string;
begin
  Sql := Trim(ASql).ToUpperInvariant;
  Result := Sql.StartsWith('SELECT');
end;

function TIBMCPSqlValidator.IsCrudStatement(const ASql: string): Boolean;
var
  Sql: string;
begin
  Sql := Trim(ASql).ToUpperInvariant;
  Result := Sql.StartsWith('INSERT') or Sql.StartsWith('UPDATE') or Sql.StartsWith('DELETE') or Sql.StartsWith('TRUNCATE');
end;

function TIBMCPSqlValidator.IsDbaStatement(const ASql: string): Boolean;
var
  Sql: string;
begin
  Sql := Trim(ASql).ToUpperInvariant;
  Result := Sql.StartsWith('CREATE') or Sql.StartsWith('ALTER') or Sql.StartsWith('DROP') or Sql.StartsWith('GRANT') or Sql.StartsWith('REVOKE') or Sql.StartsWith('SET');
end;

function TIBMCPSqlValidator.ReturnsCursor(const ASql: string): Boolean;
begin
  // Keep ReturnsCursor for compatibility; currently only SELECT returns a cursor
  Result := IsViewStatement(ASql);
end;

function TIBMCPSqlValidator.ValidateSql(const ASql: string): TIBMCPSqlValidationResult;
var
  Keyword: string;
begin
  if Trim(ASql) = '' then
    Exit(TIBMCPSqlValidationResult.Reject('SQL text is required.'));

  if HasForbiddenKeyword(ASql, Keyword) then
    Exit(TIBMCPSqlValidationResult.Reject('Forbidden SQL keyword detected: ' + Keyword));

  Result := TIBMCPSqlValidationResult.Allow('Permitted SQL statement.');
end;

end.

