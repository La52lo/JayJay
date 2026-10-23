unit MessageBuilder;

{
  message_builder.pas
  -------------------
  Assembles Keysight B1500A FLEX command strings.

  Each method appends one FLEX command to an internal buffer.
  Call .Message to retrieve the complete string (buffer is reset).
  Send the result via TVisaTransport.Write or .Ask.

  Method naming mirrors the QCoDeS MessageBuilder class.

  Reference: Keysight B1500A Programming Guide, Chapter 4 (FLEX Commands)

  Fixed vs ori ginal
  -----------------
  * Removed duplicate Append implementation (caused "duplicate identifier"
    compile error in FPC). The private method is now named AppendCmd to
    avoid any ambiguity with inherited methods.
  * FlexFloat now uses a local TFormatSettings to guarantee '.' as decimal
    separator regardless of OS locale, replacing the fragile post-hoc
    StringReplace approach.
}



interface

uses
  SysUtils, B1500Constants;

type
  TMessageBuilder = class
  private
    FBuf : string;
    { Appends s to the buffer, separated by ';' if the buffer is non-empty }
    procedure AppendCmd(const s: string);
  public
    constructor Create;

    { Retrieve the assembled command string and reset the buffer }
    function Message: string;

    { Reset the buffer without reading }
    procedure Clear;

    { -------------------------------------------------------------- }
    { System / mainframe commands                                      }
    { -------------------------------------------------------------- }

    { *CAL? – self calibration query (blocks on instrument until done) }
    function CalQuery: TMessageBuilder;

    { *IDN? – identification query }
    function IdnQuery: TMessageBuilder;

    { *RST – reset }
    function Rst: TMessageBuilder;

    { FMT format, mode – set output data format
        format 1 = ASCII 12-digit with header, CRLF+EOI
        mode   0 = only measurement data (default)
               1 = measurement data + source data             }
    function Fmt(format: Integer = 1; mode: Integer = 0): TMessageBuilder;

    { UNT? mode – query installed modules }
    function UntQuery(mode: TUNTMode = untModuleInfoOnly): TMessageBuilder;

    { ERR? – query error code }
    function ErrQuery: TMessageBuilder;

    { -------------------------------------------------------------- }
    { Channel enable / disable                                         }
    { -------------------------------------------------------------- }

    { CN chnum – enable (connect) a single channel }
    function CN(chnum: TChannelNr): TMessageBuilder; overload;
    { CN chnums – enable multiple channels in one command }
    function CN(const chnums: array of TChannelNr): TMessageBuilder; overload;

    { CL chnum – disable (disconnect) a single channel }
    function CL(chnum: TChannelNr): TMessageBuilder; overload;
    { CL chnums – disable multiple channels in one command }
    function CL(const chnums: array of TChannelNr): TMessageBuilder; overload;

    { -------------------------------------------------------------- }
    { Voltage forcing (SMU)                                            }
    { -------------------------------------------------------------- }

    { DV chnum, vrange, voltage, icomp
        Force a DC voltage on channel chnum.
        vrange  : TVOutputRange (0 = auto)
        voltage : value in Volts
        icomp   : current compliance in Amperes (default 0.1 A)  }
    function DV(chnum   : TChannelNr;
                vrange  : TVOutputRange;
                voltage : Double;
                icomp   : Double = 0.1): TMessageBuilder;

    { -------------------------------------------------------------- }
    { Spot measurement commands                                        }
    { -------------------------------------------------------------- }

    { TV chnum, vrange – spot voltage measurement }
    function TV(chnum : TChannelNr;
                vrange: TVMeasRange = vmrAuto): TMessageBuilder;

    { TI chnum, irange – spot current measurement }
    function TI(chnum : TChannelNr;
                irange: TIMeasRange = imrAuto): TMessageBuilder;

    /// <summary>
    /// Configures Measurement Mode: MM <mode>, <ch1> [, <ch2>]
    /// Mode 1 = Spot Measurement
    /// </summary>
    function MM(AMode: Integer; const AChannels: array of TChannelNr): TMessageBuilder;
    function CMM(AChannel: TChannelNr; AMode: Integer): TMessageBuilder;
    /// <summary>
    /// Executes measurement: XE
    /// </summary>
    function XE: TMessageBuilder;
    function MY_AIT(AChannel: TChannelNr) : TMessageBuilder;
    function MY_RI(AChannel: TChannelNr) : TMessageBuilder;
    function MY_RM(AChannel: TChannelNr) : TMessageBuilder;
    function MY_FL(AChannel: TChannelNr) : TMessageBuilder;


  end;

{ Format a Double for FLEX commands.
  Always uses '.' decimal separator, 6 significant figures, E notation. }
function FlexFloat(v: Double): string;

implementation

{ ------------------------------------------------------------------ }
{ FlexFloat                                                            }
{ ------------------------------------------------------------------ }

function FlexFloat(v: Double): string;
begin
  Result := Format('%.6E', [v], TFormatSettings.Invariant);
end;

{ ------------------------------------------------------------------ }
{ TMessageBuilder                                                      }
{ ------------------------------------------------------------------ }

constructor TMessageBuilder.Create;
begin
  inherited Create;
  FBuf := '';
end;

procedure TMessageBuilder.AppendCmd(const s: string);
begin
  if FBuf = '' then
    FBuf := s
  else
    FBuf := FBuf + ';' + s;
end;

function TMessageBuilder.Message: string;
begin
  Result := FBuf;
  FBuf   := '';
end;

procedure TMessageBuilder.Clear;
begin
  FBuf := '';
end;

{ ------------------------------------------------------------------ }
{ System commands                                                      }
{ ------------------------------------------------------------------ }

function TMessageBuilder.CalQuery: TMessageBuilder;
begin
  AppendCmd('*CAL?');
  Result := Self;
end;

function TMessageBuilder.IdnQuery: TMessageBuilder;
begin
  AppendCmd('*IDN?');
  Result := Self;
end;

function TMessageBuilder.Rst: TMessageBuilder;
begin
  AppendCmd('*RST');
  Result := Self;
end;

function TMessageBuilder.Fmt(format: Integer; mode: Integer): TMessageBuilder;
begin
  AppendCmd(SysUtils.Format('FMT %d,%d', [format, mode]));
  Result := Self;
end;

function TMessageBuilder.UntQuery(mode: TUNTMode): TMessageBuilder;
begin
  AppendCmd(SysUtils.Format('UNT? %d', [Ord(mode)]));
  Result := Self;
end;

function TMessageBuilder.ErrQuery: TMessageBuilder;
begin
  AppendCmd('ERR?');
  Result := Self;
end;

{ ------------------------------------------------------------------ }
{ Channel enable / disable                                             }
{ ------------------------------------------------------------------ }

function TMessageBuilder.CN(chnum: TChannelNr): TMessageBuilder;
begin
  AppendCmd(SysUtils.Format('CN %d', [Ord(chnum)]));
  Result := Self;
end;

function TMessageBuilder.CN(const chnums: array of TChannelNr): TMessageBuilder;
var
  i : Integer;
  s : string;
begin
  s := 'CN';
  for i := 0 to High(chnums) do
  begin
    if i = 0 then s := s + ' ' + IntToStr(Ord(chnums[i]))
    else           s := s + ',' + IntToStr(Ord(chnums[i]));
  end;
  AppendCmd(s);
  Result := Self;
end;

function TMessageBuilder.CL(chnum: TChannelNr): TMessageBuilder;
begin
  AppendCmd(SysUtils.Format('CL %d', [Ord(chnum)]));
  Result := Self;
end;

function TMessageBuilder.CL(const chnums: array of TChannelNr): TMessageBuilder;
var
  i : Integer;
  s : string;
begin
  s := 'CL';
  for i := 0 to High(chnums) do
  begin
    if i = 0 then s := s + ' ' + IntToStr(Ord(chnums[i]))
    else           s := s + ',' + IntToStr(Ord(chnums[i]));
  end;
  AppendCmd(s);
  Result := Self;
end;

{ ------------------------------------------------------------------ }
{ Voltage forcing                                                      }
{ ------------------------------------------------------------------ }

function TMessageBuilder.DV(chnum: TChannelNr; vrange: TVOutputRange;
  voltage: Double; icomp: Double): TMessageBuilder;
begin
  AppendCmd(SysUtils.Format('DV %d,%d,%s,%s',
    [Ord(chnum), Ord(vrange), FlexFloat(voltage), FlexFloat(icomp)]));
  Result := Self;
end;

{ ------------------------------------------------------------------ }
{ Spot measurement                                                     }
{ ------------------------------------------------------------------ }

function TMessageBuilder.TV(chnum: TChannelNr; vrange: TVMeasRange): TMessageBuilder;
begin
  AppendCmd(SysUtils.Format('TV %d,%d', [Ord(chnum), Ord(vrange)]));
  Result := Self;
end;

function TMessageBuilder.TI(chnum: TChannelNr; irange: TIMeasRange): TMessageBuilder;
begin
  AppendCmd(SysUtils.Format('TI %d,%d', [Ord(chnum), Ord(irange)]));
  Result := Self;
end;

function TMessageBuilder.MM(AMode: Integer; const AChannels: array of TChannelNr): TMessageBuilder;
var
  I: Integer;
  ChStr: string;
begin
  ChStr := '';
  for I := Low(AChannels) to High(AChannels) do
  begin
    if I = Low(AChannels) then
      ChStr := IntToStr(Ord(AChannels[I]))
    else
      ChStr := ChStr + ',' + IntToStr(Ord(AChannels[I]));
  end;

  AppendCmd(SysUtils.Format('MM %d,%s', [AMode, ChStr]));
  Result := Self;
end;

function TMessageBuilder.CMM(AChannel: TChannelNr; AMode: Integer): TMessageBuilder;
begin
    AppendCmd(SysUtils.Format('CMM %d,%d', [Ord(AChannel), AMode]));
    Result:=Self;
end;

function TMessageBuilder.XE: TMessageBuilder;
begin
  AppendCmd('XE');
  Result := Self;
end;

function TMessageBuilder.MY_AIT(AChannel: TChannelNr) : TMessageBuilder;
begin
  AppendCmd(SysUtils.Format('AIT %d,%d,8', [Ord(AChannel),Ord(TAITMode.adcPLC)]));
  Result := Self;
end;

function TMessageBuilder.MY_RI(AChannel: TChannelNr) : TMessageBuilder;
begin
  AppendCmd(SysUtils.Format('RI %d,%d',[Ord(AChannel),RANGE_LIMIT_10mA]));
  Result := Self;
end;

function TMessageBuilder.MY_RM(AChannel: TChannelNr) : TMessageBuilder;
begin
  AppendCmd(SysUtils.Format('RM %d,%d,%d',[Ord(AChannel),AUTORANGE_MODE_UP,
          AUTORANGE_THRESHOLD_50_PERCENT]));
           Result := Self;
end;

function TMessageBuilder.MY_FL(AChannel: TChannelNr) : TMessageBuilder;
begin
 AppendCmd(SysUtils.Format('FL %d,%d',[Ord(TFilterActive.filterON),Ord(AChannel)]));
  Result := Self;
end;

end.
