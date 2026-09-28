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
  SysUtils;

{ ------------------------------------------------------------------ }
{ VISA type aliases                                                    }
{ ------------------------------------------------------------------ }
type
  ViStatus   = LongInt;
  ViSession  = LongWord;
  ViUInt32   = LongWord;
  ViBoolean  = Word;        { VI_TRUE=1, VI_FALSE=0 }
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
{$ELSE}
const VISALIB = 'libvisa.so';
{$ENDIF}

function viOpenDefaultRM(out sesn: ViSession): ViStatus;
  cdecl; external VISALIB name 'viOpenDefaultRM';

function viOpen(sesn: ViSession; rsrcName: PChar; accessMode: ViUInt32;
  openTimeout: ViUInt32; out vi: ViSession): ViStatus;
  cdecl; external VISALIB name 'viOpen';

function viClose(vi: ViSession): ViStatus;
  cdecl; external VISALIB name 'viClose';

function viClear(vi: ViSession): ViStatus;
  cdecl; external VISALIB name 'viClear';

function viWrite(vi: ViSession; buf: PChar; count: ViUInt32;
  out retCount: ViUInt32): ViStatus;
  cdecl; external VISALIB name 'viWrite';

function viRead(vi: ViSession; buf: PChar; count: ViUInt32;
  out retCount: ViUInt32): ViStatus;
  cdecl; external VISALIB name 'viRead';

function viSetAttribute(vi: ViSession; attrName: ViUInt32;
  attrValue: ViUInt32): ViStatus;
  cdecl; external VISALIB name 'viSetAttribute';

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

procedure TVisaTransport.CheckStatus(status: ViStatus; const context: string);
begin
  if status < VI_SUCCESS then
    raise EVISAError.CreateFmt(
      'VISA error 0x%.8X in %s  (resource: %s)',
      [LongWord(status), context, FAddr]);
end;

constructor TVisaTransport.Create(const resourceAddress: string;
  timeoutMs: LongWord);
var
  st : ViStatus;
begin
  inherited Create;
  FAddr   := resourceAddress;
  FRM     := VI_NULL;
  FInstr  := VI_NULL;

  { Open the default resource manager }
  st := viOpenDefaultRM(FRM);
  CheckStatus(st, 'viOpenDefaultRM');

  { Open the instrument session }
  st := viOpen(FRM, PChar(resourceAddress), VI_NO_LOCK, 0, FInstr);
  CheckStatus(st, 'viOpen("' + resourceAddress + '")');

  { --- Replicate QCoDeS VisaInstrument.__init__ setup ------------- }

  { 1. I/O timeout }
  st := viSetAttribute(FInstr, VI_ATTR_TMO_VALUE, timeoutMs);
  CheckStatus(st, 'viSetAttribute(VI_ATTR_TMO_VALUE)');

  { 2. Termination character = LF (#10), matching QCoDeS '\n' default }


  st := viSetAttribute(FInstr, VI_ATTR_TERMCHAR,10 ); {Ord(#10)}
  CheckStatus(st, 'viSetAttribute(VI_ATTR_TERMCHAR)');

  st := viSetAttribute(FInstr, VI_ATTR_TERMCHAR_EN, VI_TRUE);
  CheckStatus(st, 'viSetAttribute(VI_ATTR_TERMCHAR_EN)');

  { 3. Assert EOI on last write byte (standard GPIB practice)
  st := viSetAttribute(FInstr, VI_ATTR_SEND_END_EN, VI_TRUE);
  CheckStatus(st, 'viSetAttribute(VI_ATTR_SEND_END_EN)');   }

  { 4. Device clear – QCoDeS VisaInstrument does this by default
       (device_clear=True). Flushes any stale data from a previous
       session.                                                       }
  st := viClear(FInstr);
  CheckStatus(st, 'viClear');
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
  buf      : string;
begin
  buf := cmd;   { append LF terminator }
  st  := viWrite(FInstr, PChar(buf), Length(buf), retCount);
  CheckStatus(st, 'viWrite("' + cmd + '")');
end;

function TVisaTransport.Ask(const cmd: string): string;
const
  BUFSIZE = 1024;
var
  st       : ViStatus;
  retCount : ViUInt32;
  buf      : array[0..BUFSIZE-1] of Char;
begin
  Write(cmd);
  FillChar(buf, SizeOf(buf), 0);
  st := viRead(FInstr, @buf[0], BUFSIZE-1, retCount);
  CheckStatus(st, 'viRead (after "' + cmd + '")');
  Result := Trim(string(buf));
end;

end.
