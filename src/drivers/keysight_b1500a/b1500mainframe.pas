unit B1500Mainframe;

interface

uses
  SysUtils, VisaTransport, B1500Constants, MessageBuilder,
  B1500Module, b1511b;

const
  DEFAULT_TIMEOUT_MS = 10000;
  CAL_TIMEOUT_MS = 30000;

type
  EB1500Error = class(Exception);

  TB1500 = class
  private
    FTransport: TVisaTransport;
    FSMU1: TB1511B;
    FSMU2: TB1511B;
    procedure RawWrite(const cmd: string);
    function RawAsk(const cmd: string): string;
    procedure CheckInstrumentError(const context: string);
    procedure FindModules;
    function GetConnected: Boolean;
  public
    constructor Create(const gpibAddress: string;
      timeoutMs: LongWord = DEFAULT_TIMEOUT_MS);
    destructor Destroy; override;
    procedure Write(const cmd: string);
    function Ask(const cmd: string): string;
    procedure SelfCalibration;
    procedure DisableAllChannels;
    procedure SetDataFormat(const AFormatStr: string = '1,0');
    procedure SetMeasurementModeSpot(const AChannels: array of TChannelNr);
    procedure SetMeasurementModeSpotIV(AChannel: TChannelNr; AMode: Integer);
    procedure EnableChannels(const AChannels: array of TChannelNr);
    procedure SetMeasurementConfig;
    procedure SetIntegrationTimePLC(APLC: Integer = 1;
      AADCType: TADCType = adcHighResolution);
    procedure AllChannelSaveAndZero;
    procedure AllChannelRestore;
    function ExecuteSynchronousMeasurement: TFMTResponseArray;
    function ExecuteMeasurementRaw: string;

    { Start a staircase voltage sweep on SMU1 and stream each current result
      as a (voltage, resistance) pair to AOnSample. Returns samples relayed.
      AVoltages must describe the linear staircase configured by WV. }
    function ExecuteStaircaseStream(const AVoltages: TArray<Double>;
      AInitialWait, AMeasureTime: Double;
      const AOnSample: TProc<Double, Double>): Integer;

    { Execute a staircase voltage sweep on SMU1, measuring its current,
      and return Abs(V/I) for each sweep point. A zero/near-zero current
      produces the established 1e12 Ohm open-circuit sentinel. }
    function AutoSweepResistance(AStart, AStop: Double; ASteps: Integer;
      ACurrentCompliance: Double; AHoldTime: Double = 0;
      ADelayTime: Double = 0): TArray<Double>;

    property SMU1: TB1511B read FSMU1;
    property SMU2: TB1511B read FSMU2;
    property Connected: Boolean read GetConnected;
  end;

implementation

constructor TB1500.Create(const gpibAddress: string; timeoutMs: LongWord);
var
  MB: TMessageBuilder;
begin
  inherited Create;
  FSMU1 := nil;
  FSMU2 := nil;
  FTransport := TVisaTransport.Create(gpibAddress, timeoutMs);
  MB := TMessageBuilder.Create;
  try
    Write(MB.Rst.Fmt().Message);
    FindModules;
    EnableChannels([Channel_1, Channel_2]);
    SetMeasurementConfig;
    AllChannelSaveAndZero;
  finally
    MB.Free;
  end;
end;

destructor TB1500.Destroy;
begin
  try
    if Assigned(FTransport) then
      DisableAllChannels;
  except
  end;
  FreeAndNil(FSMU1);
  FreeAndNil(FSMU2);
  FreeAndNil(FTransport);
  inherited;
end;

procedure TB1500.RawWrite(const cmd: string);
begin
  FTransport.Write(cmd);
end;

function TB1500.RawAsk(const cmd: string): string;
begin
  Result := FTransport.Ask(cmd);
end;

procedure TB1500.CheckInstrumentError(const context: string);
var
  Resp: string;
  Code: string;
begin
  Resp := Trim(RawAsk('ERRX?'));
  if (Length(Resp) >= 2) and (Resp[1] = '+') then
  begin
    Code := Copy(Resp, 2, 1);
    if Code = '0' then Exit;
  end;
  raise EB1500Error.CreateFmt('B1500 instrument error after "%s": %s',
    [context, Resp]);
end;

procedure TB1500.Write(const cmd: string);
begin
  RawWrite(cmd);
  CheckInstrumentError(cmd);
end;

function TB1500.Ask(const cmd: string): string;
begin
  Result := RawAsk(cmd);
end;

procedure TB1500.FindModules;
var
  Slots: TSlotModelArray;
  I, Count: Integer;
  Raw, SMUMsg: string;
begin
  Raw := RawAsk('UNT? 0');
  Slots := ParseModuleQueryResponse(Raw);
  Count := 0;
  for I := 0 to High(Slots) do
    if (Slots[I].Model = MODEL_B1511B) or (Slots[I].Model = MODEL_B1511A) then
    begin
      Inc(Count);
      case Count of
        1: FSMU1 := TB1511B.Create(Write, Ask, TChannelNr(Slots[I].SlotNr));
        2: FSMU2 := TB1511B.Create(Write, Ask, TChannelNr(Slots[I].SlotNr));
      end;
    end;
  if Count = 0 then
    raise EB1500Error.Create('FindModules: no B1511B/B1511A found. UNT? response: ' + Raw);
  SMUMsg := Format('Found %d B1511B module(s). SMU1=ch%d',
    [Count, Ord(FSMU1.Channel)]);
  if Assigned(FSMU2) then
    SMUMsg := SMUMsg + Format(', SMU2=ch%d', [Ord(FSMU2.Channel)]);
end;

function TB1500.GetConnected: Boolean;
begin
  Result := FTransport <> nil;
end;

procedure TB1500.SetMeasurementConfig;
var
  MB: TMessageBuilder;
begin
  MB := TMessageBuilder.Create;
  try
    Write(MB.MY_AAD(Channel_1)
      .MY_AIT(Channel_2).MY_AIT(Channel_1)
      .MY_FL(Channel_2).MY_FL(Channel_1)
      .MY_RI(Channel_2).MY_RI(Channel_1)
      .CMM(Channel_1, 1).CMM(Channel_2, 2)
      .DV(Channel_2, vorAuto, 0.0, 0.1)
      .MM(1, [Channel_1, Channel_2]).Message);
  finally
    MB.Free;
  end;
end;

procedure TB1500.SetIntegrationTimePLC(APLC: Integer; AADCType: TADCType);
begin
  Write(Format('AIT %d,2,%s', [Ord(AADCType), IntToStr(APLC)]));
end;

procedure TB1500.SetDataFormat(const AFormatStr: string);
begin
  Write('FMT ' + AFormatStr);
end;

procedure TB1500.SetMeasurementModeSpot(const AChannels: array of TChannelNr);
var
  MB: TMessageBuilder;
begin
  MB := TMessageBuilder.Create;
  try
    Write(MB.MM(1, AChannels).Message);
  finally
    MB.Free;
  end;
end;

procedure TB1500.SetMeasurementModeSpotIV(AChannel: TChannelNr; AMode: Integer);
var
  MB: TMessageBuilder;
begin
  MB := TMessageBuilder.Create;
  try
    Write(MB.CMM(AChannel, AMode).Message);
  finally
    MB.Free;
  end;
end;

procedure TB1500.EnableChannels(const AChannels: array of TChannelNr);
var
  I: Integer;
  ChList: string;
begin
  ChList := '';
  for I := Low(AChannels) to High(AChannels) do
    if I = Low(AChannels) then
      ChList := IntToStr(Ord(AChannels[I]))
    else
      ChList := ChList + ',' + IntToStr(Ord(AChannels[I]));
  Write('CN ' + ChList);
  if Assigned(FSMU1) then FSMU1.IsEnabled := True;
  if Assigned(FSMU2) then FSMU2.IsEnabled := True;
  Sleep(30);
end;

function TB1500.ExecuteSynchronousMeasurement: TFMTResponseArray;
begin
  Result := ParseFMTResponse(Ask('XE'));
end;

function TB1500.ExecuteMeasurementRaw: string;
begin
  Result := Ask('XE');
end;

function TB1500.ExecuteStaircaseStream(const AVoltages: TArray<Double>;
  AInitialWait, AMeasureTime: Double;
  const AOnSample: TProc<Double, Double>): Integer;
const
  { FMT 5 is 3 header bytes + 12 ASCII measurement bytes + comma. }
  FMT5_RECORD_BYTES = 16;
  MIN_CURRENT = 1e-14;
var
  MB: TMessageBuilder;
  I, PLC: Integer;
  RawRecord: AnsiString;
  Header, ValueText: string;
  Current, Voltage, Resistance: Double;
  Settings: TFormatSettings;
  FmtRestored, TerminatorRestored: Boolean;
begin
  Result := 0;
  if Length(AVoltages) = 0 then
    Exit;
  if not Assigned(FSMU1) then
    raise EB1500Error.Create('ExecuteStaircaseStream requires SMU1.');
  if not Assigned(AOnSample) then
    raise EArgumentNilException.Create('AOnSample callback must be assigned.');
  if AMeasureTime < 0 then
    raise EArgumentOutOfRangeException.Create('Measurement time cannot be negative.');

  { WV specifies a linear sweep. Require the supplied point list to match
    that sweep so the callback voltage stays aligned with each current. }
  if Length(AVoltages) > 2 then
    for I := 1 to High(AVoltages) - 1 do
      if Abs((AVoltages[I] - AVoltages[I - 1]) -
        (AVoltages[1] - AVoltages[0])) >
        1e-9 * Max(1.0, Abs(AVoltages[I])) then
        raise EArgumentException.Create(
          'Staircase sweep voltages must be evenly spaced.');

  PLC := Round(AMeasureTime / 0.02);
  if PLC < 1 then
    PLC := 1;
  Settings := TFormatSettings.Invariant;
  FmtRestored := False;
  TerminatorRestored := False;
  MB := TMessageBuilder.Create;
  try
    try
      { Configure measurement time and staircase current measurement. }
      SetIntegrationTimePLC(PLC);
      Write(MB.CMM(FSMU1.Channel, 1)
        .MM(2, [FSMU1.Channel])
        .WM(2, 1)
        .WT(AInitialWait, 0)
        .WV(FSMU1.Channel, 1, vorAuto, AVoltages[0],
          AVoltages[High(AVoltages)], Length(AVoltages), 0.1)
        .Message);

      { Set FMT while LF termination is still active; Write performs ERRX?. }
      Write(MB.FmtCommaTerminated.Message);
      FTransport.SetReadTermination(',', True);

      { Do not call Write here: its ERRX? query would consume/interleave with
        the measurement stream. XE output is read directly below. }
      RawWrite(MB.XE.Message);

      for I := 0 to High(AVoltages) do
      begin
        RawRecord := FTransport.ReadExact(FMT5_RECORD_BYTES);
        if (Length(RawRecord) <> FMT5_RECORD_BYTES) or
           (RawRecord[FMT5_RECORD_BYTES] <> ',') then
          raise EConvertError.CreateFmt(
            'Malformed FMT 5 sweep record at point %d: "%s"',
            [I + 1, string(RawRecord)]);

        Header := Copy(string(RawRecord), 1, 3);
        ValueText := Trim(Copy(string(RawRecord), 4, 12));
        if (Header[1] <> 'N') and (Header[1] <> 'C') and
           (Header[1] <> 'T') and (Header[1] <> 'V') and
           (Header[1] <> 'O') and (Header[1] <> 'F') and
           (Header[1] <> 'G') and (Header[1] <> 'X') then
          raise EConvertError.CreateFmt(
            'Unexpected FMT 5 status header at point %d: "%s"',
            [I + 1, Header]);
        if Header[3] <> 'I' then
          raise EConvertError.CreateFmt(
            'Expected current measurement in FMT 5 record at point %d, got "%s".',
            [I + 1, Header]);
        if not TryStrToFloat(ValueText, Current, Settings) then
          raise EConvertError.CreateFmt(
            'Cannot parse FMT 5 current value at point %d: "%s"',
            [I + 1, ValueText]);

        Voltage := AVoltages[I];
        if Abs(Current) > MIN_CURRENT then
          Resistance := Abs(Voltage / Current)
        else
          Resistance := 1e12;
        AOnSample(Voltage, Resistance);
        Inc(Result);
      end;
    finally
      { Restore LF before issuing the checked FMT command (whose ERRX? reply
        is line-terminated), even if parsing or the callback raised. }
      try
        FTransport.SetReadTermination(#10, True);
        TerminatorRestored := True;
      finally
        if TerminatorRestored then
        begin
          Write('FMT 1,0');
          FmtRestored := True;
        end;
      end;
    end;
  finally
    MB.Free;
  end;
end;

procedure TB1500.SelfCalibration;
var
  Resp: string;
begin
  FTransport.SetTimeout(CAL_TIMEOUT_MS);
  try
    Resp := Trim(RawAsk('*CAL?'));
  finally
    FTransport.SetTimeout(DEFAULT_TIMEOUT_MS);
  end;
  if Resp <> '0' then
    raise EB1500Error.Create('Self-calibration failed. Instrument response: ' + Resp);
end;

procedure TB1500.DisableAllChannels;
begin
  RawWrite('CL');
  if Assigned(FSMU1) then FSMU1.IsEnabled := False;
  if Assigned(FSMU2) then FSMU2.IsEnabled := False;
end;

procedure TB1500.AllChannelSaveAndZero;
var
  MB: TMessageBuilder;
begin
  MB := TMessageBuilder.Create;
  try
    Write(MB.DZ.Message);
  finally
    MB.Free;
  end;
end;

procedure TB1500.AllChannelRestore;
var
  MB: TMessageBuilder;
begin
  MB := TMessageBuilder.Create;
  try
    Write(MB.RZ.Message);
  finally
    MB.Free;
  end;
end;

function TB1500.AutoSweepResistance(AStart, AStop: Double; ASteps: Integer;
  ACurrentCompliance: Double; AHoldTime, ADelayTime: Double): TArray<Double>;
var
  Currents: TArray<Double>;
  I: Integer;
  Voltage, Current: Double;
begin
  if not Assigned(FSMU1) then
    raise EB1500Error.Create('AutoSweepResistance requires SMU1.');
  if ASteps < 1 then
    raise EArgumentOutOfRangeException.Create('Sweep step count must be at least one.');

  Currents := FSMU1.StaircaseVoltageSweepCurrent(AStart, AStop, ASteps,
    ACurrentCompliance, AHoldTime, ADelayTime);
  SetLength(Result, Length(Currents));
  for I := 0 to High(Currents) do
  begin
    if ASteps = 1 then
      Voltage := AStart
    else
      Voltage := AStart + (AStop - AStart) * I / (ASteps - 1);
    Current := Currents[I];
    if Abs(Current) > 1e-14 then
      Result[I] := Abs(Voltage / Current)
    else
      Result[I] := 1e12;
  end;
end;

end.
