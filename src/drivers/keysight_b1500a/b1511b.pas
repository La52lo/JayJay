unit b1511b;

{
  b1511b.pas
  ----------
  Driver for the Keysight B1511B Medium Power SMU module.

  Mirrors:
    QCoDeS keysightb1500/KeysightB1511B.py  (class KeysightB1511B)

  Fixes vs first version
  ----------------------
  * TB1511B no longer holds a TVisaTransport directly. It now holds a
    reference to a WriteCmd/AskCmd callback pair provided by the
    mainframe (TB1500). This means all writes go through TB1500.Write,
    which checks ERR? after every command - exactly as the QCoDeS
    KeysightB1500.write() override does. In the original, TB1511B
    bypassed the error-checking write entirely.

  The callback approach avoids a circular-unit reference
  (b1511b <-> b1500_mainframe) while preserving the parent-child
  relationship that InstrumentChannel has in QCoDeS.
}


interface

uses
  SysUtils, B1500Constants, MessageBuilder, B1500Module;

type
  { Callback types - the mainframe supplies these so that TB1511B
    always routes through the error-checking Write/Ask.           }
  TWriteProc = procedure(const cmd: string) of object;
  TAskFunc   = function (const cmd: string): string of object;

  /// <summary>
  /// Measurement readings extracted for an SMU from a spot acquisition.
  /// </summary>
  TSMUSpotReading = record
    Voltage : Double;
    Current : Double;
    Status  : TMeasurementStatusEnum;
  end;

  TB1511B = class
  private
    FWriteProc  : TWriteProc;
    FAskFunc    : TAskFunc;
    FChannel    : TChannelNr;
    FVOutRange  : TVOutputRange;
    FVMeasRange : TVMeasRange;
    FIMeasRange : TIMeasRange;
    FCompliance : Double;
    FEnabled    : Boolean;

    procedure SendCmd(const cmd: string);
    function  QueryInstr(const cmd: string): string;
  public
    { writeProc / askFunc must be the mainframe's Write / Ask methods
      so that every command passes through the post-write ERR? check. }
    constructor Create(writeProc : TWriteProc;
                       askFunc   : TAskFunc;
                       channel   : TChannelNr);
    destructor  Destroy; override;

    { enable_outputs()  -> CN chnum }
    procedure EnableOutputs;

    { disable_outputs() -> CL chnum }
    procedure DisableOutputs;

    { source_config(output_range, compliance)
      Stores parameters; applied on the next SetVoltage call.
      Mirrors the lazy QCoDeS behaviour.                       }
    procedure SourceConfig(outputRange: TVOutputRange;
                           compliance : Double);

    { voltage(v) - SET - DV command }
    procedure SetVoltage(v: Double);

    { voltage() - GET - TV command }
    function  GetVoltage: Double;

    { current() - GET - TI command }
    function  GetCurrent: Double;

    /// <summary>
    /// Triggers synchronous execution (XE) and returns the spot measurement value.
    /// </summary>
    function MeasureSpot: Double;

    { v_measure_range_config / i_measure_range_config }
    procedure VMeasRangeConfig(vrange: TVMeasRange);
    procedure IMeasRangeConfig(irange: TIMeasRange);
    function ExtractReading(const ARawResponse: string): TSMUSpotReading;

    property Channel   : TChannelNr read FChannel;
    property IsEnabled : Boolean    read FEnabled write FEnabled;
  end;

implementation

{ ------------------------------------------------------------------ }

constructor TB1511B.Create(writeProc: TWriteProc; askFunc: TAskFunc;
  channel: TChannelNr);
begin
  inherited Create;
  FWriteProc  := writeProc;
  FAskFunc    := askFunc;
  FChannel    := channel;
  FVOutRange  := vorAuto;
  FVMeasRange := vmrAuto;
  FIMeasRange := imrAuto;
  FCompliance := 0.1;    { 100 mA default - safe for B1511B }
  FEnabled    := False;
end;

destructor TB1511B.Destroy;
begin
  if FEnabled then
    try DisableOutputs except end;
  inherited;
end;

procedure TB1511B.SendCmd(const cmd: string);
begin
  FWriteProc(cmd);   { routes through TB1500.Write -> ERR? check }
end;

function TB1511B.QueryInstr(const cmd: string): string;
begin
  Result := FAskFunc(cmd);   { routes through TB1500.Ask }
end;

{ ------------------------------------------------------------------ }

procedure TB1511B.EnableOutputs;
var
  mb : TMessageBuilder;
  nr : TChannelNr;
begin
  nr := FChannel;
  mb := TMessageBuilder.Create;
  try
    SendCmd(mb.CN(nr).Message);
    FEnabled := True;
  finally
    mb.Free;
  end;
end;

procedure TB1511B.DisableOutputs;
var
  mb : TMessageBuilder;
begin
  mb := TMessageBuilder.Create;
  try
    SendCmd(mb.CL(FChannel).Message);
    FEnabled := False;
  finally
    mb.Free;
  end;
end;

procedure TB1511B.SourceConfig(outputRange: TVOutputRange; compliance: Double);
begin
  FVOutRange  := outputRange;
  FCompliance := compliance;
end;



procedure TB1511B.SetVoltage(v: Double);
var
  mb : TMessageBuilder;
begin
  if not FEnabled then
    EnableOutputs;

  mb := TMessageBuilder.Create;
  try
    SendCmd(mb.DV(FChannel, FVOutRange, v, FCompliance).Message);
  finally
    mb.Free;
  end;
end;

function TB1511B.GetVoltage: Double;
var
  mb  : TMessageBuilder;
  raw : string;
begin
  if not FEnabled then
    EnableOutputs;

  mb := TMessageBuilder.Create;
  try
    raw := QueryInstr(mb.TV(FChannel, FVMeasRange).Message);
  finally
    mb.Free;
  end;
  Result := ParseSpotMeasurement(raw);
end;

function TB1511B.GetCurrent: Double;
var
  mb  : TMessageBuilder;
  raw : string;
begin
  if not FEnabled then
    EnableOutputs;

  mb := TMessageBuilder.Create;
  try
    raw := QueryInstr(mb.TI(FChannel, FIMeasRange).Message);
  finally
    mb.Free;
  end;
  Result := ParseSpotMeasurement(raw);
end;

function TB1511B.MeasureSpot: Double;
var
  mb  : TMessageBuilder;
  raw : string;
begin
  if not FEnabled then
    EnableOutputs;

  mb := TMessageBuilder.Create;
  try
    // Trigger measurement using XE
    raw := QueryInstr(mb.XE.Message);
  finally
    mb.Free;
  end;

  Result := ParseSpotMeasurement(raw);
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
  Result.Status  := msNormal;

  // Parse raw comma-separated string into module tokens
  Tokens := ParseFMTResponse(ARawResponse);

  for Token in Tokens do
  begin
    if Token.Channel = FChannel then
    begin
      Result.Status := Token.Status;
      if Token.DataType = dtVoltage then
        Result.Voltage := Token.Value
      else if Token.DataType = dtCurrent then
        Result.Current := Token.Value;
    end;
  end;
end;

end.
