unit MessageBuilder;

{
  message_builder.pas
  -------------------
  Assembles Keysight B1500A FLEX command strings.
}

interface

uses
  SysUtils, B1500Constants;

type
  TMessageBuilder = class
  private
    FBuf : string;
    procedure AppendCmd(const s: string);
  public
    constructor Create;
    function Message: string;
    procedure Clear;

    { System / mainframe commands }
    function CalQuery: TMessageBuilder;
    function IdnQuery: TMessageBuilder;
    function Rst: TMessageBuilder;
    function Fmt(format: Integer = 1; mode: Integer = 0): TMessageBuilder;
    function UntQuery(mode: TUNTMode = untModuleInfoOnly): TMessageBuilder;
    function ErrQuery: TMessageBuilder;

    { Channel enable / disable }
    function CN(chnum: TChannelNr): TMessageBuilder; overload;
    function CN(const chnums: array of TChannelNr): TMessageBuilder; overload;
    function CL(chnum: TChannelNr): TMessageBuilder; overload;
    function CL(const chnums: array of TChannelNr): TMessageBuilder; overload;

    { Voltage forcing }
    function DV(chnum: TChannelNr; vrange: TVOutputRange;
      voltage: Double; icomp: Double = 0.1): TMessageBuilder;

    { Spot measurement commands }
    function TV(chnum: TChannelNr; vrange: TVMeasRange = vmrAuto): TMessageBuilder;
    function TI(chnum: TChannelNr; irange: TIMeasRange = imrAuto): TMessageBuilder;
    function MM(AMode: Integer; const AChannels: array of TChannelNr): TMessageBuilder;
    function CMM(AChannel: TChannelNr; AMode: Integer): TMessageBuilder;
    function XE: TMessageBuilder;

    { Staircase sweep commands, per Keysight B1500 Programming Guide }
    function WM(AAbort, APost: Integer = 1): TMessageBuilder;
    function WT(AHold, ADelay: Double; AStepDelay: Double = 0;
      ASourceTriggerDelay: Double = 0; AMeasurementTriggerDelay: Double = 0): TMessageBuilder;
    function WV(AChannel: TChannelNr; AMode: Integer; ARange: TVOutputRange;
      AStart, AStop: Double; ASteps: Integer; ACurrentCompliance: Double = 0.1;
      APowerCompliance: Double = 0): TMessageBuilder;

    function MY_AIT(AChannel: TChannelNr): TMessageBuilder;
    function MY_RI(AChannel: TChannelNr): TMessageBuilder;
    function MY_RM(AChannel: TChannelNr): TMessageBuilder;
    function MY_FL(AChannel: TChannelNr): TMessageBuilder;
    function MY_AAD(AChannel: TChannelNr): TMessageBuilder;
    function DZ: TMessageBuilder;
    function RZ: TMessageBuilder;
  end;

function FlexFloat(v: Double): string;

implementation

function FlexFloat(v: Double): string;
begin
  Result := Format('%.6E', [v], TFormatSettings.Invariant);
end;

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
  FBuf := '';
end;

procedure TMessageBuilder.Clear;
begin
  FBuf := '';
end;

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

function TMessageBuilder.CN(chnum: TChannelNr): TMessageBuilder;
begin
  AppendCmd(SysUtils.Format('CN %d', [Ord(chnum)]));
  Result := Self;
end;

function TMessageBuilder.CN(const chnums: array of TChannelNr): TMessageBuilder;
var
  I: Integer;
  S: string;
begin
  S := 'CN';
  for I := Low(chnums) to High(chnums) do
    if I = Low(chnums) then
      S := S + ' ' + IntToStr(Ord(chnums[I]))
    else
      S := S + ',' + IntToStr(Ord(chnums[I]));
  AppendCmd(S);
  Result := Self;
end;

function TMessageBuilder.CL(chnum: TChannelNr): TMessageBuilder;
begin
  AppendCmd(SysUtils.Format('CL %d', [Ord(chnum)]));
  Result := Self;
end;

function TMessageBuilder.CL(const chnums: array of TChannelNr): TMessageBuilder;
var
  I: Integer;
  S: string;
begin
  S := 'CL';
  for I := Low(chnums) to High(chnums) do
    if I = Low(chnums) then
      S := S + ' ' + IntToStr(Ord(chnums[I]))
    else
      S := S + ',' + IntToStr(Ord(chnums[I]));
  AppendCmd(S);
  Result := Self;
end;

function TMessageBuilder.DV(chnum: TChannelNr; vrange: TVOutputRange;
  voltage, icomp: Double): TMessageBuilder;
begin
  AppendCmd(SysUtils.Format('DV %d,%d,%s,%s',
    [Ord(chnum), Ord(vrange), FlexFloat(voltage), FlexFloat(icomp)]));
  Result := Self;
end;

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
    if I = Low(AChannels) then
      ChStr := IntToStr(Ord(AChannels[I]))
    else
      ChStr := ChStr + ',' + IntToStr(Ord(AChannels[I]));
  AppendCmd(SysUtils.Format('MM %d,%s', [AMode, ChStr]));
  Result := Self;
end;

function TMessageBuilder.CMM(AChannel: TChannelNr; AMode: Integer): TMessageBuilder;
begin
  AppendCmd(SysUtils.Format('CMM %d,%d', [Ord(AChannel), AMode]));
  Result := Self;
end;

function TMessageBuilder.XE: TMessageBuilder;
begin
  AppendCmd('XE');
  Result := Self;
end;

function TMessageBuilder.WM(AAbort, APost: Integer): TMessageBuilder;
begin
  AppendCmd(SysUtils.Format('WM %d,%d', [AAbort, APost]));
  Result := Self;
end;

function TMessageBuilder.WT(AHold, ADelay, AStepDelay,
  ASourceTriggerDelay, AMeasurementTriggerDelay: Double): TMessageBuilder;
begin
  AppendCmd(SysUtils.Format('WT %s,%s,%s,%s,%s',
    [FlexFloat(AHold), FlexFloat(ADelay), FlexFloat(AStepDelay),
     FlexFloat(ASourceTriggerDelay), FlexFloat(AMeasurementTriggerDelay)]));
  Result := Self;
end;

function TMessageBuilder.WV(AChannel: TChannelNr; AMode: Integer;
  ARange: TVOutputRange; AStart, AStop: Double; ASteps: Integer;
  ACurrentCompliance, APowerCompliance: Double): TMessageBuilder;
var
  S: string;
begin
  S := SysUtils.Format('WV %d,%d,%d,%s,%s,%d,%s',
    [Ord(AChannel), AMode, Ord(ARange), FlexFloat(AStart), FlexFloat(AStop),
     ASteps, FlexFloat(ACurrentCompliance)]);
  if APowerCompliance > 0 then
    S := S + ',' + FlexFloat(APowerCompliance);
  AppendCmd(S);
  Result := Self;
end;

function TMessageBuilder.MY_AIT(AChannel: TChannelNr): TMessageBuilder;
begin
  AppendCmd(SysUtils.Format('AIT %d,%d,8', [Ord(AChannel), Ord(TAITMode.adcPLC)]));
  Result := Self;
end;

function TMessageBuilder.MY_AAD(AChannel: TChannelNr): TMessageBuilder;
begin
  AppendCmd(SysUtils.Format('AAD %d,1', [Ord(AChannel)]));
  Result := Self;
end;

function TMessageBuilder.MY_RI(AChannel: TChannelNr): TMessageBuilder;
begin
  AppendCmd(SysUtils.Format('RI %d,%d', [Ord(AChannel), RANGE_LIMIT_100nA_AUTOUP]));
  Result := Self;
end;

function TMessageBuilder.MY_RM(AChannel: TChannelNr): TMessageBuilder;
begin
  AppendCmd(SysUtils.Format('RM %d,%d,%d', [Ord(AChannel), AUTORANGE_MODE_UP,
    AUTORANGE_THRESHOLD_50_PERCENT]));
  Result := Self;
end;

function TMessageBuilder.MY_FL(AChannel: TChannelNr): TMessageBuilder;
begin
  AppendCmd(SysUtils.Format('FL %d,%d', [Ord(TFilterActive.filterON), Ord(AChannel)]));
  Result := Self;
end;

function TMessageBuilder.DZ: TMessageBuilder;
begin
  AppendCmd('DZ');
  Result := Self;
end;

function TMessageBuilder.RZ: TMessageBuilder;
begin
  AppendCmd('RZ');
  Result := Self;
end;

end.
