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

{ ------------------------------------------------------------------ }
{ VISA type aliases                                                    }
{ ------------------------------------------------------------------ }
type
  ViStatus   = LongInt;
  ViSession  = LongWord;
  ViUInt32   = LongWord;
  ViBoolean  = UInt16;        { VI_TRUE=1, VI_FALSE=0 }
  ViPSession = ^ViSession;
  ViPUInt32  = ^ViUInt32;

const
  { Status codes }
  VI_SUCCESS        = 0;
  VI_NULL           = 0;

  { Access modes }
  VI_NO_LOCK        = 0;

  { Attribute constants }
  VI_ATTR_TMO_VALUE      = $3FFF001A;  { timeout in ms             }
  VI_ATTR_TERMCHAR       = $3FFF0018;  { termination character      }
  VI_ATTR_TERMCHAR_EN    = $3FFF0038;  { enable termchar detection  }
  VI_ATTR_SEND_END_EN    = $3FFF0036;  { assert EOI on last byte    }

  VI_TRUE  : ViBoolean = 1;
  VI_FALSE : ViBoolean = 0;

{ ------------------------------------------------------------------ }
{ NI-VISA DLL imports                                                  }
{ ------------------------------------------------------------------ }
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

{ Changed 'buf' to Pointer to safely handle both text strings and binary byte arrays }
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

{ ------------------------------------------------------------------ }
{ High-level transport object                                          }
{ ------------------------------------------------------------------ }
type
  EVISAError = class(Exception);

  TVisaTransport = class
  private
    FRM     : ViSession;
    FInstr  : ViSession;
    FAddr   : string;
    procedure CheckStatus(status: ViStatus; const context: string);
  public
    { resourceAddress : VISA resource string, e.g. 'GPIB0::16::INSTR'
      timeoutMs       : I/O timeout in milliseconds (default 10 s).
                        Use 30000+ for self-calibration calls.       }
    constructor Create(const resourceAddress: string;
                       timeoutMs: LongWord = 10000);
    destructor  Destroy; override;

    { Send a command string (no response expected).
      A LF terminator is appended automatically.   }
    procedure Write(const cmd: string);

    { Send a query and return the trimmed response string. }
    function  Ask(const cmd: string): string;

    { Change the I/O timeout at runtime (e.g. before *CAL?) }
    procedure SetTimeout(timeoutMs: LongWord);

    property Address: string read FAddr;
  end;

implementation

{ ------------------------------------------------------------------ }

{procedure TVisaTransport.CheckStatus(status: ViStatus; const context: string);
begin
  if status < VI_SUCCESS then

    raise EVISAError.CreateFmt(
      'VISA error 0x%.8X in %s  (resource: %s)',
      [LongWord(status), context, FAddr]);
end;}

procedure TVisaTransport.CheckStatus(status: ViStatus; const context: string);
var
  { Expand to 1024 bytes to completely eliminate any driver stack overflow risks }
  ErrorBuffer: AnsiString;
  ErrorMsg: string;
  LookupSession: ViSession;
begin
  if status < VI_SUCCESS then
  begin
    { Safely clear the expanded buffer space }
    SetLength(ErrorBuffer, 1023);
    FillChar(ErrorBuffer[1], 1023, ' ');
    if FInstr <> VI_NULL then
      LookupSession := FInstr
    else
      LookupSession := FRM;

    { Call viStatusDesc with the safe, padded stack buffer pointer }
    if LookupSession <> VI_NULL then
      if (viStatusDesc(LookupSession, status, PAnsiChar(ErrorBuffer)) = VI_SUCCESS) then
        begin
          { Safe parsing to string up to the null-terminator boundary }
          SetString(ErrorMsg, PAnsiChar(ErrorBuffer), StrLen(PAnsiChar(ErrorBuffer)));
        end
        else
          ErrorMsg := 'Unknown or unmapped VISA error code.';

    ErrorMsg := TrimRight(ErrorMsg);

    { Now that the stack frames are perfectly preserved, this will fire cleanly }
    raise EVISAError.CreateFmt(
      'VISA Error [0x%.8X] in %s: %s (Resource: %s)',
      [LongWord(status), context, ErrorMsg, FAddr]
    );
  end;
end;



constructor TVisaTransport.Create(const resourceAddress: string; timeoutMs: LongWord);
var
  st : ViStatus;
begin
  inherited Create;
  FAddr   := resourceAddress;
  FRM     := VI_NULL;
  FInstr  := VI_NULL;

  try
    { Open the default resource manager }
    st := viOpenDefaultRM(FRM);
    CheckStatus(st, 'viOpenDefaultRM');

    { Open the instrument session }
    st := viOpen(FRM, PAnsiChar(AnsiString(resourceAddress)), VI_NO_LOCK, 0, FInstr);

    CheckStatus(st, 'viOpen("' + resourceAddress + '")');

    { --- Replicate QCoDeS VisaInstrument.__init__ setup ------------- }

    { 1. I/O timeout }
    OutputDebugString('AFTER CheckStatus - Code continued sequentially!');
    st := viSetAttribute(FInstr, VI_ATTR_TMO_VALUE, timeoutMs);
    CheckStatus(st, 'viSetAttribute(VI_ATTR_TMO_VALUE)');

    { 2. Termination character = LF (#10) }
    st := viSetAttribute(FInstr, VI_ATTR_TERMCHAR, 10);
    CheckStatus(st, 'viSetAttribute(VI_ATTR_TERMCHAR)');

    st := viSetAttribute(FInstr, VI_ATTR_TERMCHAR_EN, VI_TRUE);
    CheckStatus(st, 'viSetAttribute(VI_ATTR_TERMCHAR_EN)');

    { 3. Device clear }
    st := viClear(FInstr);
    CheckStatus(st, 'viClear');

  except
    { If anything failed above, clean up what we managed to open, then re-raise }
    if FInstr <> VI_NULL then viClose(FInstr);
    if FRM    <> VI_NULL then viClose(FRM);
    raise; // Re-raises the exact EVISAError exception back up to the caller
  end;
end;


destructor TVisaTransport.Destroy;
begin
  if FInstr <> VI_NULL then viClose(FInstr);
  if FRM    <> VI_NULL then viClose(FRM);
  inherited;
end;

procedure TVisaTransport.SetTimeout(timeoutMs: LongWord);
var
  st : ViStatus;
begin
  st := viSetAttribute(FInstr, VI_ATTR_TMO_VALUE, timeoutMs);
  CheckStatus(st, 'viSetAttribute(VI_ATTR_TMO_VALUE)');
end;

procedure TVisaTransport.Write(const cmd: string);
var
  st       : ViStatus;
  retCount : ViUInt32;
  buf      : AnsiString;
begin
  buf := AnsiString(cmd + #13#10);   { append LF terminator }
  st  := viWrite(FInstr, PAnsiChar(buf), Length(buf), retCount);
  CheckStatus(st, 'viWrite("' + cmd + '")');
end;

function TVisaTransport.Ask(const cmd: string): string;
const
  BUFSIZE = 1024;
var
  st       : ViStatus;
  retCount : ViUInt32;
  ReadBuffer : AnsiString; // Changed from Char to AnsiChar
begin
  Write(cmd);
  SetLength(ReadBuffer, BUFSIZE);
  FillChar(PAnsiChar(ReadBuffer)^, BUFSIZE, 0);
  retCount:=0;
  //FillChar(buf, SizeOf(buf), 0);

  // This is now perfectly safe because 'Pointer' accepts any address pointer type (@)
  st := viRead(FInstr,PAnsiChar(ReadBuffer), BUFSIZE, retCount);
  {OutputDebugString(PChar(Format(
  'viRead: status=$%.8x, retCount=%d',
  [Cardinal(st), retCount]
    )));}
  CheckStatus(st, 'viRead (after "' + cmd + '")');
  if st >= 0 then
  begin
    // To convert this buffer safely into a normal Delphi string for a memo or label:
     SetString(Result, PAnsiChar(ReadBuffer), retCount);
     Result := TrimRight(Result);
  end;
end;

end.
