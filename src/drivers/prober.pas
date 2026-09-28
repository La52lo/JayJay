unit Prober;

interface

uses
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  System.RegularExpressions,
  Winapi.Windows,
  VisaTransport,
  AnnealTypes;

// ---------------------------------------------------------------------------
// TProberController
// ---------------------------------------------------------------------------

type
  TProberController = class
  private
    FAddress: string;
    FInstrument: TVisaTransport;
    FExeDir: string;
    FLastStdOut: string;

    function RunExe(const AExeName: string): Integer;
    class function ParseCoord(const AStdOut: string): TProberCoord; static;
    class function StringAfterLast(const S, Marker: string): string; static;

  public
    constructor Create(const AExeDir: string);

    procedure CheckProberExecutables;
    procedure Connect;
    function Start: TProberCoord;
    function NextSubsite: TProberCoord;
    procedure Finish;
    procedure Disconnect;

    property ExeDir: string read FExeDir;
  end;

procedure SleepSeconds(ASeconds: Double);

implementation

// ---------------------------------------------------------------------------
// SleepSeconds
// ---------------------------------------------------------------------------

procedure SleepSeconds(ASeconds: Double);
begin
  Sleep(Round(ASeconds * 1000));
end;

// ---------------------------------------------------------------------------
// Constructor
// ---------------------------------------------------------------------------

constructor TProberController.Create(const AExeDir: string);
begin
  inherited Create;

  FExeDir := AExeDir;
  FLastStdOut := '';

  CheckProberExecutables;
end;

// ---------------------------------------------------------------------------
// Connect
// ---------------------------------------------------------------------------

procedure TProberController.Connect;
begin
  FInstrument := TVisaTransport.Create(FAddress);
end;

// ---------------------------------------------------------------------------
// Disconnect
// ---------------------------------------------------------------------------

procedure TProberController.Disconnect;
begin
  FreeAndNil(FInstrument);
end;

// ---------------------------------------------------------------------------
// CheckProberExecutables
// ---------------------------------------------------------------------------

procedure TProberController.CheckProberExecutables;
const
  Exes: array[0..2] of string = (
    'Start_apw.exe',
    'Subsite_apw.exe',
    'Final_apw.exe'
  );
var
  I: Integer;
  Path: string;
begin
  for I := Low(Exes) to High(Exes) do
  begin
    Path := IncludeTrailingPathDelimiter(FExeDir) + Exes[I];

    if not FileExists(Path) then
      raise EFileNotFoundException.CreateFmt(
        'Apollowave executable not found: %s',
        [Path]
      );
  end;
end;

// ---------------------------------------------------------------------------
// RunExe
//
// Runs an executable, waits for it to finish and captures stdout.
// ---------------------------------------------------------------------------

function TProberController.RunExe(const AExeName: string): Integer;
var
  SI: TStartupInfo;
  PI: TProcessInformation;
  SA: TSecurityAttributes;
  ReadPipe: THandle;
  WritePipe: THandle;
  CmdLine: string;
  Buffer: array[0..4095] of Byte;
  BytesRead: DWORD;
  Output: TBytes;
  OutputLength: Integer;
  ExitCode: DWORD;
begin
  Result := -1;
  FLastStdOut := '';

  ZeroMemory(@SA, SizeOf(SA));
  SA.nLength := SizeOf(SA);
  SA.bInheritHandle := True;

  if not CreatePipe(ReadPipe, WritePipe, @SA, 0) then
    RaiseLastOSError;

  try
    // The read handle must NOT be inherited.
    SetHandleInformation(ReadPipe, HANDLE_FLAG_INHERIT, 0);

    ZeroMemory(@SI, SizeOf(SI));
    SI.cb := SizeOf(SI);
    SI.dwFlags := STARTF_USESTDHANDLES;
    SI.hStdOutput := WritePipe;
    SI.hStdError := WritePipe;

    ZeroMemory(@PI, SizeOf(PI));

    CmdLine :=
      '"' +
      IncludeTrailingPathDelimiter(FExeDir) +
      AExeName +
      '"';

    if not CreateProcess(
      nil,
      PChar(CmdLine),
      nil,
      nil,
      True,
      0,
      nil,
      PChar(FExeDir),
      SI,
      PI
    ) then
      RaiseLastOSError;

    // The child has its own copy of the write handle.
    CloseHandle(WritePipe);
    WritePipe := 0;

    try
      // Read stdout while the process is running.
      SetLength(Output, 0);
      OutputLength := 0;

      repeat
        if not ReadFile(
          ReadPipe,
          Buffer,
          SizeOf(Buffer),
          BytesRead,
          nil
        ) then
          Break;

        if BytesRead > 0 then
        begin
          SetLength(Output, OutputLength + BytesRead);
          Move(
            Buffer[0],
            Output[OutputLength],
            BytesRead
          );
          Inc(OutputLength, BytesRead);
        end;

      until BytesRead = 0;

      // Wait for process termination.
      WaitForSingleObject(PI.hProcess, INFINITE);

      if not GetExitCodeProcess(PI.hProcess, ExitCode) then
        RaiseLastOSError;

      Result := ExitCode;

      if OutputLength > 0 then
        FLastStdOut := TEncoding.UTF8.GetString(Output);

    finally
      CloseHandle(PI.hThread);
      CloseHandle(PI.hProcess);
    end;

  finally
    CloseHandle(ReadPipe);

    if WritePipe <> 0 then
      CloseHandle(WritePipe);
  end;

  if Result <> 0 then
    WriteLn(
      Format(
        '[ProberController] Warning: %s returned code %d.',
        [AExeName, Result]
      )
    );
end;

// ---------------------------------------------------------------------------
// StringAfterLast
// ---------------------------------------------------------------------------

class function TProberController.StringAfterLast(
  const S, Marker: string): string;
var
  Idx: Integer;
begin
  Idx := LastDelimiter(Marker, S);

  if Idx <= 0 then
    Exit('');

  Result := Copy(
    S,
    Idx + Length(Marker),
    MaxInt
  );
end;

function TrimLeftZeros(const S: string): string;
begin
  Result := S;

  while (Length(Result) > 1) and (Result[1] = '0') do
    Delete(Result, 1, 1);
end;



// ---------------------------------------------------------------------------
// ParseCoord
// ---------------------------------------------------------------------------

class function TProberController.ParseCoord(
  const AStdOut: string): TProberCoord;
var
  CoordStr: string;
  Tokens: TArray<string>;
  Match: TMatch;
  SubsiteTokens: TArray<string>;
begin
  Result.Break := False;

  if Pos('<Break>True</Break>', AStdOut) > 0 then
  begin
    Result.Break := True;
    Exit;
  end;

  // x and y: everything after the last " : "
  CoordStr := Trim(
    StringAfterLast(AStdOut, ' : ')
  );

  if CoordStr = '' then
    raise EInvalidOp.CreateFmt(
      'Cannot parse prober coordinates from: %s',
      [AStdOut]
    );

  Tokens := CoordStr.Split(
    [' ', #9],
    TStringSplitOptions.ExcludeEmpty
  );

  if Length(Tokens) < 2 then
    raise EInvalidOp.CreateFmt(
      'Expected at least x and y in: %s',
      [CoordStr]
    );

  Result.Chip_X := StrToInt(Tokens[0]);
  Result.Chip_Y := StrToInt(Tokens[1]);

  // -------------------------------------------------------------------------
  // Subsite
  // -------------------------------------------------------------------------

  Match := TRegEx.Create(
    '<Subsite>(.*?)</Subsite>',
    [roIgnoreCase, roSingleLine]
  ).Match(AStdOut);

  if not Match.Success then
    raise EInvalidOp.CreateFmt(
      'Cannot parse <Subsite> tag from: %s',
      [AStdOut]
    );

  SubsiteTokens := Match.Groups[1].Value.Split(
    [' ', #9],
    TStringSplitOptions.ExcludeEmpty
  );

  if Length(SubsiteTokens) < 3 then
    raise EInvalidOp.CreateFmt(
      'Invalid <Subsite> data: %s',
      [Match.Groups[1].Value]
    );

  Result.Subsite := SubsiteTokens[0];

  Result.Subsite_X :=
    StrToInt(
  TrimLeftZeros(Copy(SubsiteTokens[1], 1, 5)) +
  Copy(SubsiteTokens[1], 5, 6)
) ;
  Result.Subsite_Y :=
  StrToInt(
    TrimLeftZeros(Copy(SubsiteTokens[2], 1, 7)) +
    Copy(SubsiteTokens[2], 7, 12)
  );
end;

// ---------------------------------------------------------------------------
// Start
// ---------------------------------------------------------------------------

function TProberController.Start: TProberCoord;
begin
  RunExe('Start_apw.exe');
  Result := ParseCoord(FLastStdOut);
end;

// ---------------------------------------------------------------------------
// NextSubsite
// ---------------------------------------------------------------------------

function TProberController.NextSubsite: TProberCoord;
begin
  SleepSeconds(0.1);

  RunExe('Subsite_apw.exe');

  SleepSeconds(0.1);

  Result := ParseCoord(FLastStdOut);
end;

// ---------------------------------------------------------------------------
// Finish
// ---------------------------------------------------------------------------

procedure TProberController.Finish;
begin
  RunExe('Final_apw.exe');
end;

end.
