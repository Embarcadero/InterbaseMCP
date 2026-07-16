unit IB.SqlValidator;

interface

uses
  System.Generics.Collections,
  Dext.Options,
  IB.MCP.Settings;

type
  /// <summary>
  /// Result of SQL validation.
  /// </summary>
  TSqlValidationResult = record
    Accepted: Boolean;
    Reason: string;
    Warning: string;
    class function Allow(const AWarning: string = ''): TSqlValidationResult; static;

    class function Reject(const AReason: string): TSqlValidationResult; static;
  end;

  /// <summary>
  /// Validates SQL against configured safety rules.
  /// </summary>
  TSqlValidator = class
  private
    FSettings: TIBMCPSettings;
    FOwnsSettings: Boolean;
    FEmaByTool: TDictionary<string, Double>;

    function HasDangerousKeyword(const ASql: string; out AKeyword: string): Boolean;
    function StatementKind(const ASql: string): string;
  public
    constructor Create; overload;

    destructor Destroy; override;

    /// <summary>
    /// Validates a SQL statement.
    /// </summary>
    /// <param name="ASql">SQL text to validate.</param>
    /// <param name="AAllowWrites">Allows writes when enabled by settings.</param>
    /// <returns>Validation outcome.</returns>
    function ValidateSql(const ASql: string; AAllowWrites: Boolean = False): TSqlValidationResult;
  end;

implementation

uses
  System.StrUtils,
  System.SysUtils;

  { TSqlValidationResult }

  class function TSqlValidationResult.Allow(const AWarning: string): TSqlValidationResult;
begin
  Result.Accepted := True;
  Result.Reason := '';
  Result.Warning := AWarning;
end;

class function TSqlValidationResult.Reject(const AReason: string): TSqlValidationResult;
begin
  Result.Accepted := False;
  Result.Reason := AReason;
  Result.Warning := '';
end;

{ TSqlValidator }

constructor TSqlValidator.Create;
begin
  inherited Create;
  FSettings := TIBMCPSettings.Create;
  FOwnsSettings := True;
  FEmaByTool := TDictionary<string, Double>.Create;
end;

destructor TSqlValidator.Destroy;
begin
  FEmaByTool.Free;
  if FOwnsSettings then
    FSettings.Free;
  inherited Destroy;
end;

function TSqlValidator.HasDangerousKeyword(const ASql: string; out AKeyword: string): Boolean;
var
  Keywords: TArray<string>;
  Keyword: string;
  NormalizedKeyword: string;
  NormalizedSql: string;
begin
  Result := False;
  AKeyword := '';
  NormalizedSql := ' ' + ASql.ToUpperInvariant + ' ';
  Keywords := FSettings.DangerousKeywords.Split([',']);
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

function TSqlValidator.StatementKind(const ASql: string): string;
var
  Sql: string;
begin
  Sql := Trim(ASql).ToUpperInvariant;
  if Sql.StartsWith('EXECUTE PROCEDURE') then
    Exit('EXECUTE PROCEDURE');
  if Sql.StartsWith('EXECUTE BLOCK') then
    Exit('EXECUTE BLOCK');
  if Sql.StartsWith('SELECT') then
    Exit('SELECT');
  if Sql.StartsWith('UPDATE') then
    Exit('UPDATE');
  if Sql.StartsWith('INSERT') then
    Exit('INSERT');
  if Sql.StartsWith('DELETE') then
    Exit('DELETE');
  Result := '';
end;

function TSqlValidator.ValidateSql(const ASql: string; AAllowWrites: Boolean): TSqlValidationResult;
var
  Keyword: string;
  Kind: string;
begin
  if Trim(ASql) = '' then
    Exit(TSqlValidationResult.Reject('SQL text is required.'));

  if HasDangerousKeyword(ASql, Keyword) then
    Exit(TSqlValidationResult.Reject('Dangerous SQL keyword is not allowed: ' + Keyword));

  Kind := StatementKind(ASql);
  if (Kind = 'SELECT') or (Kind = 'EXECUTE PROCEDURE') or (Kind = 'EXECUTE BLOCK') then
    Exit(TSqlValidationResult.Allow);

  if (Kind = 'UPDATE') or (Kind = 'INSERT') or (Kind = 'DELETE') then begin
    if FSettings.AllowWrites and AAllowWrites then
      Exit(TSqlValidationResult.Allow);
    Exit(TSqlValidationResult.Reject('Write statements require AllowWrites=true.'));
  end;

  Result := TSqlValidationResult.Reject('Statement type is not allowlisted.');
end;

end.

