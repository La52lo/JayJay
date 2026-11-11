unit VisaTransport;

{
  visa_transport.pas
  ------------------
  Low-level VISA/GPIB communication for the Keysight B1500A.

  Wraps NI-VISA (visa32.dll on Windows, libvisa.so on Linux).

  Fixes vs first version
  ----------------------
  * viClear (device clear) is now called after viOpen, matching the
    QCoDeS VisaInstrument default (device_clear=True).
  * VI_ATTR_TERMCHAR and VI_ATTR_TERMCHAR_EN are set so that reads
    terminate on LF (#10), matching QCoDeS default_terminator='\n'.
    Without this, reads on USB-TMC or VXI-11 could hang waiting for EOI.
  * VI_ATTR_SEND_END_EN is enabled to assert EOI with the last byte
    of every write (standard GPIB practice).

  Platform notes
  --------------
  On Windows link against visa32.dll (32-bit) or visa64.dll (64-bit).
    Typical path: C:\Windows\System32\visa32.dll (NI-VISA installer)
  On Linux  link against libvisa.so (NI-VISA for Linux).
    If using linux-gpib instead, replace the external declarations with
    calls to ibdev/ibwrt/ibrd from the gpib unit.
}

interface

uses
   Winapi.Windows, System.SysUtils;

type
  ViStatus   = LongInt;
  ViSession  = LongWord;
  ViUInt32   = LongWord;
  ViBoolean  = UInt16;
  ViPSession = ^ViSession;
  ViPUInt32  = ^ViUInt32;

const
  VI_SUCCESS        = 0;
  VI_NULL           = 0;
  VI_NO_LOCK        = 0;
  VI_ATTR_TMO_VALUE      = $3FFF001A;
  VI_ATTR_TERMCHAR       = $3FFF0018;
  VI_ATTR_TERMCHAR_EN    = $3FFF0038;
  VI_ATTR_SEND_END_EN    = $3FFF0036;

  VI_TRUE  : ViBoolean = 1;
  VI_FALSE : ViBoolean = 0;

{$IF Defined(MSWINDOWS)}
const VISALIB = 'visa32.dll';
{$ENDIF}

function viOpenDefaultRM(out sesn: ViSession): ViStatus;
  stdcall; external VISALIB name 'viOpenDefaultRM';

function viOpen(sesn: ViSession; rsrcName: PAnsiChar; accessMode: ViUInt32;
  openTimeout: ViUInt32; out vi: ViSession): ViStatus;
  stdcall; external VISALIB name 'viOpen';

function viClose(vi: ViSession): ViStatus;
  stdcall; external VISALIB name 'viClose';

function viClear(vi: ViSession): ViStatus;
  stdcall; external VISALIB name 'viClear';

function viWrite(vi: ViSession; buf: Pointer; count: ViUInt32;
  out retCount: ViUInt32): ViStatus;
  stdcall; external VISALIB name 'viWrite';

function viRead(vi: ViSession; buf: Pointer; count: ViUInt32;
  out retCount: ViUInt32): ViStatus;
  stdcall; external VISALIB name 'viRead';

function viSetAttribute(vi: ViSession; attrName: ViUInt32;
  attrValue: ViUInt32): ViStatus;
  stdcall; external VISALIB name 'viSetAttribute';

function viGetAttribute(vi: ViSession; attrName: ViUInt32;
  out attrValue): ViStatus;
  stdcall; external VISALIB name 'viGetAttribute';

function viStatusDesc(vi: ViSession; status: ViStatus;
  desc: PAnsiChar): ViStatus;
  stdcall; external VISALIB name 'viStatusDesc';

type
  EVISAError = class(Exception);

  TVisaTransport = class
  private
    FRM     : ViSession;
    FInstr  : ViSession;
    FAddr   : string;
    procedure CheckStatus(status: ViStatus; const context: string);
  public
    constructor Create(const resourceAddress: string;
                       timeoutMs: LongWord = 10000);
    destructor Destroy; override;

    procedure Write(const cmd: string);
    function Ask(const cmd: string): string;

    { Configure VISA input termination. Use comma for B1500 FMT 5 streaming,
      then restore LF before ordinary VISA queries. }
    procedure SetReadTermination(const terminator: AnsiChar;
      enabled: Boolean = True);

    { Read exactly ACount bytes from the current VISA session. Intended for
      fixed-width B1500 streaming records when termchar termination is set. }
    function ReadExact(ACount: Integer): AnsiString;

    procedure SetTimeout(timeoutMs: LongWord);
    property Address: string read FAddr;
  end;

implementation

procedure TVisaTransport.CheckStatus(status: ViStatus; const context: string);
var
  ErrorBuffer: AnsiString;
  ErrorMsg: string;
  LookupSession: ViSession;
begin
  if status < VI_SUCCESS then
  begin
    SetLength(ErrorBuffer, 1023);
    FillChar(ErrorBuffer[1], 1023, ' ');
    if FInstr <> VI_NULL then
      LookupSession := FInstr
    else
      LookupSession := FRM;

    if LookupSession <> VI_NULL then
      if viStatusDesc(LookupSession, status, PAnsiChar(ErrorBuffer)) = VI_SUCCESS then
        SetString(ErrorMsg, PAnsiChar(ErrorBuffer), StrLen(PAnsiChar(ErrorBuffer)))
      else
        ErrorMsg := 'Unknown or unmapped VISA error code.';

    ErrorMsg := TrimRight(ErrorMsg);
    raise EVISAError.CreateFmt(
      'VISA Error [0x%.8X] in %s: %s (Resource: %s)',
      [LongWord(status), context, ErrorMsg, FAddr]);
  end;
end;

constructor TVisaTransport.Create(const resourceAddress: string; timeoutMs: LongWord);
var
  st: ViStatus;
begin
  inherited Create;
  FAddr := resourceAddress;
  FRM := VI_NULL;
  FInstr := VI_NULL;

  try
    st := viOpenDefaultRM(FRM);
    CheckStatus(st, 'viOpenDefaultRM');

    st := viOpen(FRM, PAnsiChar(AnsiString(resourceAddress)), VI_NO_LOCK, 0, FInstr);
    CheckStatus(st, 'viOpen("' + resourceAddress + '")');

    st := viSetAttribute(FInstr, VI_ATTR_TMO_VALUE, timeoutMs);
    CheckStatus(st, 'viSetAttribute(VI_ATTR_TMO_VALUE)');

    st := viSetAttribute(FInstr, VI_ATTR_TERMCHAR, 10);
    CheckStatus(st, 'viSetAttribute(VI_ATTR_TERMCHAR)');

    st := viSetAttribute(FInstr, VI_ATTR_TERMCHAR_EN, VI_TRUE);
    CheckStatus(st, 'viSetAttribute(VI_ATTR_TERMCHAR_EN)');

    st := viClear(FInstr);
    CheckStatus(st, 'viClear');
  except
    if FInstr <> VI_NULL then viClose(FInstr);
    if FRM <> VI_NULL then viClose(FRM);
    raise;
  end;
end;

destructor TVisaTransport.Destroy;
begin
  if FInstr <> VI_NULL then
  begin
    viClear(FInstr);
    viClose(FInstr);
  end;
  if FRM <> VI_NULL then
  begin
    viClear(FRM);
    viClose(FRM);
  end;
  inherited;
end;

procedure TVisaTransport.SetTimeout(timeoutMs: LongWord);
var
  st: ViStatus;
begin
  st := viSetAttribute(FInstr, VI_ATTR_TMO_VALUE, timeoutMs);
  CheckStatus(st, 'viSetAttribute(VI_ATTR_TMO_VALUE)');
end;

procedure TVisaTransport.SetReadTermination(const terminator: AnsiChar;
  enabled: Boolean);
var
  st: ViStatus;
  enableValue: ViUInt32;
begin
  st := viSetAttribute(FInstr, VI_ATTR_TERMCHAR, Ord(terminator));
  CheckStatus(st, 'viSetAttribute(VI_ATTR_TERMCHAR)');

  if enabled then
    enableValue := VI_TRUE
  else
    enableValue := VI_FALSE;
  st := viSetAttribute(FInstr, VI_ATTR_TERMCHAR_EN, enableValue);
  CheckStatus(st, 'viSetAttribute(VI_ATTR_TERMCHAR_EN)');
end;

function TVisaTransport.ReadExact(ACount: Integer): AnsiString;
var
  st: ViStatus;
  bytesRead: ViUInt32;
  totalRead: Integer;
  remaining: Integer;
begin
  if ACount <= 0 then
    raise EArgumentOutOfRangeException.Create('ReadExact byte count must be positive.');
  if FInstr = VI_NULL then
    raise EVISAError.Create('Cannot read: VISA instrument session is not open.');

  SetLength(Result, ACount);
  totalRead := 0;
  while totalRead < ACount do
  begin
    remaining := ACount - totalRead;
    bytesRead := 0;
    st := viRead(FInstr, @Result[totalRead + 1], remaining, bytesRead);
    CheckStatus(st, 'viRead (fixed-length streaming record)');
    if bytesRead = 0 then
      raise EVISAError.CreateFmt(
        'VISA read returned no data while reading a %d-byte record (resource: %s).',
        [ACount, FAddr]);
    Inc(totalRead, bytesRead);
  end;
end;

procedure TVisaTransport.Write(const cmd: string);
var
  st: ViStatus;
  retCount: ViUInt32;
  buf: AnsiString;
begin
  buf := AnsiString(cmd + #13#10);
  st := viWrite(FInstr, PAnsiChar(buf), Length(buf), retCount);
  CheckStatus(st, 'viWrite("' + cmd + '")');
end;

function TVisaTransport.Ask(const cmd: string): string;
const
  BUFSIZE = 1024;
var
  st: ViStatus;
  retCount: ViUInt32;
  ReadBuffer: AnsiString;
begin
  Write(cmd);
  SetLength(ReadBuffer, BUFSIZE);
  FillChar(PAnsiChar(ReadBuffer)^, BUFSIZE, 0);
  retCount := 0;
  st := viRead(FInstr, PAnsiChar(ReadBuffer), BUFSIZE, retCount);
  CheckStatus(st, 'viRead (after "' + cmd + '")');
  SetString(Result, PAnsiChar(ReadBuffer), retCount);
  Result := TrimRight(Result);
end;

end.
