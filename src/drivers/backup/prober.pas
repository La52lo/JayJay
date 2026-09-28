unit Prober;

{$mode ObjFPC}{$H+} {$modeswitch advancedrecords}

interface

uses
  Classes, SysUtils, Process, regexpr, VisaTransport,StrUtils,AnnealTypes;
// ---------------------------------------------------------------------------
// TProberCoord
// ---------------------------------------------------------------------------

type

  TProberController = class
  private
    FAddress    : string;
    FInstrument : TVisaTransport;   { from VisaWrapper unit }
    FExeDir    : string;
    FLastStdOut: string;
    function  RunExe(const AExeName: string): Integer;
    class function ParseCoord(const AStdOut: string): TProberCoord; static;
    class function StringAfterLast(const S, Marker: string): string; static;
  public
    constructor Create(const AExeDir: string);
    procedure Connect;
    function  Start: TProberCoord;
    function  NextSubsite: TProberCoord;
    procedure Finish;
    procedure Disconnect;   { no-op for prober; provided for uniform interface }

    property ExeDir : string read FExeDir;
  end;

 procedure SleepSeconds(ASeconds: Double);
implementation

{ ------------------------------------------------------------------ }

{ Sleep for ASeconds seconds using SysUtils.Sleep (millisecond granularity). }
procedure SleepSeconds(ASeconds: Double);
begin
  Sleep(Round(ASeconds * 1000));
end;


constructor TProberController.Create(const AExeDir: string);
begin
  inherited Create;
  FExeDir     := AExeDir;
  FLastStdOut := '';
end;
procedure TProberController.Connect;
begin
  FInstrument := TVisaTransport.Create(FAddress);
end;

procedure TProberController.Disconnect;
begin
  if Assigned(FInstrument) then
  begin
    FreeAndNil(FInstrument);
  end;
end;

function TProberController.RunExe(const AExeName: string): Integer;
var
  P      : TProcess;
  Output : TStringList;
begin
  P := TProcess.Create(nil);
  Output := TStringList.Create;
  try
    P.Executable        := IncludeTrailingPathDelimiter(FExeDir) + AExeName;
    P.Options           := [poWaitOnExit, poUsePipes];
    P.Execute;
    Output.LoadFromStream(P.Output);
    FLastStdOut := Output.Text;
    Result      := P.ExitCode;
    if Result <> 0 then
      WriteLn(Format('[ProberController] Warning: %s returned code %d.',
                     [AExeName, Result]));
  finally
    P.Free;
    Output.Free;
  end;
end;

class function TProberController.StringAfterLast(const S, Marker: string): string;
var Idx: Integer;
begin
  Idx := LastDelimiter(Marker[1], S);   { simple last-occurrence search }
  { For multi-char marker we use RPos from StrUtils }
  Idx := Length(S) - Length(S.Substring(S.LastIndexOf(Marker)));
  if Idx < 0 then Result := ''
  else            Result := S.Substring(Idx + Length(Marker));
end;

class function TProberController.ParseCoord(const AStdOut: string): TProberCoord;
var
  CoordStr : string;
  Tokens   : TStringArray;
  RE       : TRegExpr;
begin
  if pos('<Break>True</Break>',AStdOut) > 0
     then Begin
       Result.Break := True;
       exit (Result);
     end
  else Result.Break := False;
  { x and y: everything after the last ' : ', split on whitespace }
  CoordStr := Trim(StringAfterLast(AStdOut, ' : '));
  if CoordStr = '' then
    raise EInvalidOp.CreateFmt(
      'Cannot parse prober coordinates from: %s', [AStdOut]);

  Tokens := CoordStr.Split([' ', #9], TStringSplitOptions.ExcludeEmpty);
  if Length(Tokens) < 2 then
    raise EInvalidOp.CreateFmt(
      'Expected at least x and y in: %s', [CoordStr]);

  Result.Chip_X := StrToInt(Tokens[0]);
  Result.Chip_Y := StrToInt(Tokens[1]);

  { Subsite: any string between <Subsite> and </Subsite> }
  RE := TRegExpr.Create('<Subsite>(.*?)<\/Subsite>');
  try
    if RE.Exec(AStdOut) then
    begin
      Tokens := RE.Match[1].Split([' ', #9], TStringSplitOptions.ExcludeEmpty);
      Result.Subsite := Tokens[0];
      Result.Subsite_X:= StrToInt(LeftStr(Tokens[1],5).trimleft(['0']) +
                         MidStr(Tokens[1],5,6));
      Result.Subsite_X:= StrToInt(MidStr(Tokens[1],7,11).trimleft(['0']) +
                         MidStr(Tokens[1],11,12));
    end
    else
      raise EInvalidOp.CreateFmt(
        'Cannot parse <Subsite> tag from: %s', [AStdOut]);
  finally
    RE.Free;
  end;
end;

function TProberController.Start: TProberCoord;
begin
  RunExe('Start_apw.exe');
  Result := ParseCoord(FLastStdOut);
end;

function TProberController.NextSubsite: TProberCoord;
begin
  SleepSeconds(0.1);
  RunExe('Subsite_apw.exe');
  SleepSeconds(0.1);
  Result := ParseCoord(FLastStdOut);
end;

procedure TProberController.Finish;
begin
  RunExe('Final_apw.exe');
end;


end.

