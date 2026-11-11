unit b1511b;

{
  Driver for the Keysight B1511B Medium Power SMU module.
}

interface

uses
  SysUtils, B1500Constants, MessageBuilder, B1500Module;

type
  TWriteProc = procedure(const cmd: string) of object;
  TAskFunc = function(const cmd: string): string of object;

  TSMUSpotReading = record
    Voltage: Double;
    Current: Double;
    Status: TMeasurementStatusEnum;
  end;

  TB1511B = class
  private
    FWriteProc: TWriteProc;
    FAskFunc: TAskFunc;
    FChannel: TChannelNr;
    FVOutRange: TVOutputRange;
    FVMeasRange: TVMeasRange;
    FIMeasRange: TIMeasRange;
    FCompliance: Double;
    FEnabled: Boolean;
    procedure SendCmd(const cmd: string);
    function QueryInstr(const cmd: string): string;
  public
    constructor Create(writeProc: TWriteProc; askFunc: TAskFunc;
      channel: TChannelNr);
    destructor Destroy; override;
    procedure EnableOutputs;
    procedure DisableOutputs;
    procedure SourceConfig(outputRange: TVOutputRange; compliance: Double);
    procedure SetVoltage(v: Double);
    function GetVoltage: Double;
    function GetCurrent: Double;
    function MeasureSpot: Double;
    procedure VMeasRangeConfig(vrange: TVMeasRange);
    procedure IMeasRangeConfig(irange: TIMeasRange);
    function ExtractReading(const ARawResponse: string): TSMUSpotReading;

    { Configure and execute a single-channel staircase voltage sweep,
      returning measured current samples in sweep-point order. }
    function StaircaseVoltageSweepCurrent(AStart, AStop: Double;
      ASteps: Integer; ACurrentCompliance: Double; AHoldTime: Double = 0;
      ADelayTime: Double = 0): TArray<Double>;
    { Extract the current measurement token for this SMU from an XE response. }
    function ParseSweepCurrent(const ARawResponse: string;
      AExpectedPoints: Integer): TArray<Double>;

    property Channel: TChannelNr read FChannel;
    property IsEnabled: Boolean read FEnabled write FEnabled;
  end;

implementation

constructor TB1511B.Create(writeProc: TWriteProc; askFunc: TAskFunc;
  channel: TChannelNr);
begin
  inherited Create;
  FWriteProc := writeProc;
  FAskFunc := askFunc;
  FChannel := channel;
  FVOutRange := vorAuto;
  FVMeasRange := vmrAuto;
  FIMeasRange := imrAuto;
  FCompliance := 0.1;
  FEnabled := False;
end;

destructor TB1511B.Destroy;
begin
  if FEnabled then
    try DisableOutputs except end;
  inherited;
end;

procedure TB1511B.SendCmd(const cmd: string);
begin
  FWriteProc(cmd);
end;

function TB1511B.QueryInstr(const cmd: string): string;
begin
  Result := FAskFunc(cmd);
end;

procedure TB1511B.EnableOutputs;
var
  MB: TMessageBuilder;
begin
  MB := TMessageBuilder.Create;
  try
    SendCmd(MB.CN(FChannel).Message);
    FEnabled := True;
  finally
    MB.Free;
  end;
end;

procedure TB1511B.DisableOutputs;
var
  MB: TMessageBuilder;
begin
  MB := TMessageBuilder.Create;
  try
    SendCmd(MB.CL(FChannel).Message);
    FEnabled := False;
  finally
    MB.Free;
  end;
end;

procedure TB1511B.SourceConfig(outputRange: TVOutputRange; compliance: Double);
begin
  FVOutRange := outputRange;
  FCompliance := compliance;
end;

procedure TB1511B.SetVoltage(v: Double);
var
  MB: TMessageBuilder;
begin
  if not FEnabled then
    EnableOutputs;
  MB := TMessageBuilder.Create;
  try
    SendCmd(MB.DV(FChannel, FVOutRange, v, FCompliance).Message);
  finally
    MB.Free;
  end;
end;

function TB1511B.GetVoltage: Double;
var
  MB: TMessageBuilder;
  Raw: string;
begin
  if not FEnabled then EnableOutputs;
  MB := TMessageBuilder.Create;
  try
    Raw := QueryInstr(MB.TV(FChannel, FVMeasRange).Message);
  finally
    MB.Free;
  end;
  Result := ParseSpotMeasurement(Raw);
end;

function TB1511B.GetCurrent: Double;
var
  MB: TMessageBuilder;
  Raw: string;
begin
  if not FEnabled then EnableOutputs;
  MB := TMessageBuilder.Create;
  try
    Raw := QueryInstr(MB.TI(FChannel, FIMeasRange).Message);
  finally
    MB.Free;
  end;
  Result := ParseSpotMeasurement(Raw);
end;

function TB1511B.MeasureSpot: Double;
var
  MB: TMessageBuilder;
  Raw: string;
begin
  if not FEnabled then EnableOutputs;
  MB := TMessageBuilder.Create;
  try
    Raw := QueryInstr(MB.XE.Message);
  finally
    MB.Free;
  end;
  Result := ParseSpotMeasurement(Raw);
end;

procedure TB1511B.VMeasRangeConfig(vrange: TVMeasRange);
begin
  FVMeasRange := vrange;
end;

procedure TB1511B.IMeasRangeConfig(irange: TIMeasRange);
begin
  FIMeasRange := irange;
end;

function TB1511B.ExtractReading(const ARawResponse: string): TSMUSpotReading;
var
  Tokens: TFMTResponseArray;
  Token: TFMTResponse;
begin
  Result.Voltage := 0.0;
  Result.Current := 0.0;
  Result.Status := msNormal;
  Tokens := ParseFMTResponse(ARawResponse);
  for Token in Tokens do
    if Token.Channel = Ord(FChannel) then
    begin
      Result.Status := Token.Status;
      if Token.DataType = dtVoltage then
        Result.Voltage := Token.Value
      else if Token.DataType = dtCurrent then
        Result.Current := Token.Value;
    end;
end;

function TB1511B.ParseSweepCurrent(const ARawResponse: string;
  AExpectedPoints: Integer): TArray<Double>;
var
  Tokens: TFMTResponseArray;
  Token: TFMTResponse;
  I: Integer;
begin
  Tokens := ParseFMTResponse(ARawResponse);
  SetLength(Result, 0);
  for Token in Tokens do
    if (Token.Channel = Ord(FChannel)) and (Token.DataType = dtCurrent) then
    begin
      I := Length(Result);
      SetLength(Result, I + 1);
      Result[I] := Token.Value;
    end;

  if Length(Result) <> AExpectedPoints then
    raise EConvertError.CreateFmt(
      'Staircase sweep returned %d current values; expected %d. Response: %s',
      [Length(Result), AExpectedPoints, ARawResponse]);
end;

function TB1511B.StaircaseVoltageSweepCurrent(AStart, AStop: Double;
  ASteps: Integer; ACurrentCompliance: Double; AHoldTime,
  ADelayTime: Double): TArray<Double>;
var
  MB: TMessageBuilder;
  Raw: string;
begin
  if (ASteps < 1) or (ASteps > 10001) then
    raise EArgumentOutOfRangeException.Create('Sweep points must be in the range 1..10001.');
  if ACurrentCompliance <= 0 then
    raise EArgumentOutOfRangeException.Create('Current compliance must be positive.');
  if not FEnabled then
    EnableOutputs;

  MB := TMessageBuilder.Create;
  try
    { MM mode 2 selects staircase sweep; CMM 1 configures current measurement.
      WM 2 enables automatic abort and returns to the start value after sweep. }
    SendCmd(MB.CMM(FChannel, 1)
      .MM(2, [FChannel])
      .WM(2, 1)
      .WT(AHoldTime, ADelayTime)
      .WV(FChannel, 1, FVOutRange, AStart, AStop, ASteps,
        ACurrentCompliance)
      .Message);
    Raw := QueryInstr(MB.XE.Message);
  finally
    MB.Free;
  end;
  Result := ParseSweepCurrent(Raw, ASteps);
end;

end.
