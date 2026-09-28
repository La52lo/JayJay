unit AnnealManager;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, Classes, Math, StrUtils,AnnealTypes,
  B1500Mainframe,   { B1500 Parameter Analyzer driver }
  B1500Constants,   { B1500 Parameter Analyzer driver }
  HeatingStage,     { Heating Stage driver unit }
  Prober,           { Prober driver unit }
  b1511b,           { B1500 SMU }
  MeasurementObserver; {class to receive measurement points}

const
  DEFAULT_ANALYZER_ADDRESS = 'GPIB0::16::INSTR';
  DEFAULT_HEATER_ADDRESS   = 'GPIB0::7::INSTR';
  DEFAULT_PROBER_ADDRESS   = 'GPIB0::5::INSTR';
  DEFAULT_PROBER_DIR       =
    'C:\Users\B1500\Documents\voltage_annealing\apollowave';
  DEFAULT_COMPLIANCE       = 0.05;   { 50 mA }
type

  // ---------------------------------------------------------------------------
// TB1500Controller
// ---------------------------------------------------------------------------

  TB1500Controller = class
  private
    FAddress    : string;
    FCompliance : Double;
    FB1500      : TB1500;          { from KeysightB1500 unit }
    FConnected  : Boolean;
    procedure RequireConnection;
    function  GetSMU(ASmu: Integer): TB1511B;
  public
    constructor Create(const AAddress: string = DEFAULT_ANALYZER_ADDRESS;
                       ACompliance: Double = DEFAULT_COMPLIANCE);
    destructor  Destroy; override;

    { Connection }
    procedure Connect;
    procedure SelfCalibrate;
    procedure Disconnect;

    { Output control }
    procedure EnableOutputs;
    procedure DisableOutputs;

    { Voltage }
    procedure SetVoltage(ASmu: Integer; V: Double);
    function  CheckVoltage(ASmu: Integer; VExpected: Double;
                           Tolerance: Double = 0.1): Double;
    function  SetAndCheckVoltage(ASmu: Integer; V: Double;
                                 SettleTime: Double = 0.1): Double;

    { Measurement }
    function MeasureCurrent(ASmu: Integer): Double;
    function MeasureVoltageReadback(ASmu: Integer): Double;
    function MeasureResistance(VSource: Double): Double;

    property Address    : string  read FAddress;
    property Compliance : Double  read FCompliance write FCompliance;
    property Connected  : Boolean read FConnected;
  end;


  TAnnealManager = class
  private
    FAnalyzer         : TB1500Controller;
    FProber           : TProberController;
    FHeater           : THeatingStage;
    FObserver         : IMeasurementObserver;
    FSetupStatus      : TSetupStatus;
    FAnalyzerAddress  : string;
    FHeaterAddress    : string;
    FProberExeDir     : string;
    FProberAddress    : string;
    FCompliance       : Double;
    FRunSelfCal       : Boolean;

  public

    constructor Create(
                const AAnalyzerAddress : string;
                const AHeaterAddress   : string;
                const AProberAddress   : string;
                const AProberExeDir    : string;
                AObserver              : IMeasurementObserver;
                ACompliance            : Double;
                ARunSelfCal            : Boolean);

    destructor Destroy; override;

    function Initialize : Boolean;
    function ProbeResistance(AParams: TProbingParameters;TaskID : String): TProbingResult;
    procedure AnnealPulse(VPulse, AT: Double);
    function Anneal(const AParams: TAnnealParameters; TaskID : String): TAnnealResult;
    function AnnealBatch(const ASpecs : TAnnealParameterArray; TaskID : String) : TAnnealResultArray;
    function ProbeBatch(AParams: TProbingParameters; TaskID : String): TProbingResultArray;
    function IsDamaged(R, ThresholdOpen, ThresholdShort: Double): Boolean;

    procedure SendZeroVoltage();
    procedure DisconnectAll;

  end;


implementation

// ---------------------------------------------------------------------------
// TB1500Controller
// ---------------------------------------------------------------------------

constructor TB1500Controller.Create(const AAddress: string;
                                    ACompliance: Double);
begin
  inherited Create;
  FAddress    := AAddress;
  FCompliance := ACompliance;
  FB1500      := nil;
  FConnected  := False;
end;

destructor TB1500Controller.Destroy;
begin
  Disconnect;
  inherited;
end;

procedure TB1500Controller.RequireConnection;
begin
  if not FConnected then
    raise EInvalidOp.Create(
      'B1500 not connected. Call TB1500Controller.Connect first.');
end;

function TB1500Controller.GetSMU(ASmu: Integer): TB1511B;
begin
  case ASmu of
    1: Result := FB1500.SMU1;
    2: Result := FB1500.SMU2;
    else raise EArgumentOutOfRangeException.CreateFmt(
           'SMU must be 1 or 2, got %d.', [ASmu]);
  end;
end;

procedure TB1500Controller.Connect;
begin
  FB1500 := TB1500.Create(FAddress);   { driver constructor }
  {FB1500.Open;}
  FConnected := True;
  {WriteLn('Connected to B1500A at ' + FAddress);}
end;

procedure TB1500Controller.SelfCalibrate;
begin
  RequireConnection;
  {WriteLn('Starting self-calibration (may take up to 30 s) ...'); }
  try
    FB1500.SelfCalibration;
    {WriteLn('Self-calibration completed successfully.');}
  except
    on E: Exception do
      {WriteLn('Self-calibration failed: ' + E.Message);}
  end;
end;

procedure TB1500Controller.Disconnect;
begin
  DisableOutputs;
  if FConnected and Assigned(FB1500) then
  begin
    {FB1500.Close; }
    FreeAndNil(FB1500);
    FConnected := False;
    {WriteLn('B1500A disconnected.'); }
  end;
end;

procedure TB1500Controller.EnableOutputs;
begin
  RequireConnection;
  FB1500.SMU1.EnableOutputs;
  FB1500.SMU2.EnableOutputs;
end;

procedure TB1500Controller.DisableOutputs;
begin
  if not FConnected then Exit;
  try
    FB1500.SMU1.DisableOutputs;
    FB1500.SMU2.DisableOutputs;
  except
    { silently ignore — safe even if already disconnected }
  end;
end;

procedure TB1500Controller.SetVoltage(ASmu: Integer; V: Double);
var SMU: TB1511B;
begin
  RequireConnection;
  SMU := GetSMU(ASmu);
  SMU.EnableOutputs;
  SMU.SourceConfig(TVOutputRange.vorAuto, FCompliance);
  SMU.SetVoltage(V);
end;

function TB1500Controller.CheckVoltage(ASmu: Integer; VExpected: Double;
                                       Tolerance: Double): Double;
var
  SMU    : TB1511B;
  VMeas  : Double;
begin
  RequireConnection;
  SMU := GetSMU(ASmu);
  SMU.VMeasRangeConfig(vmrFix2V);
  SMU.EnableOutputs;
  VMeas := SMU.GetVoltage;
  if (VExpected <> 0.0) and
     (Abs((VExpected - VMeas) / VExpected) > Tolerance) then
    raise EInvalidOp.CreateFmt(
      'SMU%d: measured %.4f V deviates more than %.0f%% from expected %.4f V.',
      [ASmu, VMeas, Tolerance * 100, VExpected]);
  Result := VMeas;
end;

function TB1500Controller.SetAndCheckVoltage(ASmu: Integer; V: Double;
                                              SettleTime: Double): Double;
begin
  SetVoltage(ASmu, V);
  SleepSeconds(SettleTime);
  Result := CheckVoltage(ASmu, V);
end;

function TB1500Controller.MeasureCurrent(ASmu: Integer): Double;
var SMU: TB1511B;
begin
  RequireConnection;
  SMU := GetSMU(ASmu);
  SMU.IMeasRangeConfig(imrAuto);
  SMU.EnableOutputs;
  Result := SMU.GetCurrent;
end;

function TB1500Controller.MeasureVoltageReadback(ASmu: Integer): Double;
var SMU: TB1511B;
begin
  RequireConnection;
  SMU := GetSMU(ASmu);
  SMU.VMeasRangeConfig(vmrFix2V);
  SMU.EnableOutputs;
  Result := SMU.GetVoltage;
end;

function TB1500Controller.MeasureResistance(VSource: Double): Double;
var
  V1, V0, I: Double;
begin
  V1 := CheckVoltage(1, VSource);
  V0 := MeasureVoltageReadback(2);
  I  := MeasureCurrent(1);
  Result := Abs((V1 - V0) / I);
end;



function TAnnealManager.Initialize: Boolean;
var
  Temp     : Double;
begin
  Result := True;
  { --- B1500A Analyzer --- }
  FSetupStatus[0].Label_  := 'B1500A';
  FSetupStatus[0].Address := FAnalyzerAddress;
  FSetupStatus[0].Skipped := False;
  try
    FAnalyzer := TB1500Controller.Create(FAnalyzerAddress, FCompliance);;
    if FRunSelfCal then FAnalyzer.SelfCalibrate;
    FSetupStatus[0].OK      := True;
    FSetupStatus[0].Message := '';
  except
    on E: Exception do
    begin
      FreeAndNil(FAnalyzer);
      FSetupStatus[0].OK      := False;
      FSetupStatus[0].Message := E.Message;
      Result := False;
    end;
  end;

  { --- Heating Stage --- }
  FSetupStatus[1].Label_  := 'Heater';
  FSetupStatus[1].Address := FHeaterAddress;
  if FHeaterAddress = '' then
  begin
    FSetupStatus[1].Skipped := True;
    FSetupStatus[1].OK      := True;
    FSetupStatus[1].Message := 'not configured';
  end
  else
  begin
    FSetupStatus[1].Skipped := False;
    try
      FHeater := THeatingStage.Create(FHeaterAddress);
      FHeater.Connect;
      Temp := FHeater.GetTemperature;
      FSetupStatus[1].OK      := True;
      FSetupStatus[1].Message := Format('T: %.1f C', [Temp]);
    except
      on E: Exception do
      begin
        FreeAndNil(FHeater);
        FSetupStatus[1].OK      := False;
        FSetupStatus[1].Message := E.Message;
        Result := False;
      end;
    end;
  end;

  { --- Prober --- }
  FSetupStatus[2].Label_  := 'Prober';
  FSetupStatus[2].Folder := FProberExeDir;
  FSetupStatus[2].Address := FProberAddress;
  if FProberExeDir = '' then
  begin
    FSetupStatus[2].Skipped := True;
    FSetupStatus[2].OK      := True;
    FSetupStatus[2].Message := 'not configured';
  end
  else
  begin
    FSetupStatus[2].Skipped := False;
    try
      FProber := TProberController.Create(FProberExeDir);
      FProber.Connect;
      FSetupStatus[2].OK      := True;
      FSetupStatus[2].Message := 'executables found';
    except
      on E: Exception do
      begin
        FreeAndNil(FProber);
        FSetupStatus[2].OK      := False;
        FSetupStatus[2].Message := E.Message;
        Result := False;
      end;
    end;
  end;
end;

constructor TAnnealManager.Create(
                const AAnalyzerAddress : string;
                const AHeaterAddress   : string;
                const AProberAddress   : string;
                const AProberExeDir : string;
                AObserver              : IMeasurementObserver;
                ACompliance            : Double;
                ARunSelfCal            : Boolean);
begin
  inherited Create;
  FAnalyzerAddress := AAnalyzerAddress;
  FHeaterAddress   := AHeaterAddress;
  FProberExeDir    := AProberExeDir;
  FProberAddress   := AProberAddress;
  FRunSelfCal      := ARunSelfCal;
  FObserver        := AObserver;
  FObserver        := AObserver;
  FAnalyzer         := nil;
  FHeater           := nil;
  FProber           := nil;
end;

destructor TAnnealManager.Destroy;
begin
  DisconnectAll;
  inherited;
end;

function TAnnealManager.IsDamaged(R, ThresholdOpen, ThresholdShort: Double): Boolean;
begin
  Result := (R > ThresholdOpen) or (R < ThresholdShort);
end;

function TAnnealManager.ProbeResistance(AParams: TProbingParameters;
                TaskID : String):TProbingResult;
var
  DefaultVoltages : TDoubleArray;
  Voltages        : TDoubleArray;
  Count, i, j     : Integer;
  V, R            : Double;
  HWRes           : THardwareResult;
begin
  if AParams.VoltageList = nil then
  begin
    SetLength(DefaultVoltages, 4);
    DefaultVoltages[0] := -0.01;
    DefaultVoltages[1] := -0.005;
    DefaultVoltages[2] :=  0.005;
    DefaultVoltages[3] :=  0.01;
    Voltages := DefaultVoltages;
  end
  else
    Voltages := AParams.VoltageList;
  FAnalyzer.SetAndCheckVoltage(2, 0.0, 0.1);
  Count := Length(Voltages);
  SetLength(Result.Readings, Count);
  i := 0;
  FObserver.TaskStarted(TaskID);
  for V in Voltages do
  begin

    FAnalyzer.SetAndCheckVoltage(1, V, 0.1);
    SleepSeconds(0.1);
    Result.Readings[i] := FAnalyzer.MeasureResistance(V);
    Inc(i);
  end;
    FAnalyzer.DisableOutputs;

  Result.MeanResistance := MeanDoubleArray(Result.Readings);
  Result.StdResistance  := StdDoubleArray(Result.Readings);
  FObserver.Log(Format('Resistance: %.1f +/- %.1f Ohm',
                 [Result.MeanResistance, Result.StdResistance]),TaskID);
  HWRes.CommandType:=hcProbe;
  HWRes.ProbingResult:=Result;
  FObserver.TaskFinished(HWRes,TaskID);
end;

procedure TAnnealManager.AnnealPulse(VPulse, AT: Double);

begin
  FAnalyzer.SetVoltage(2, 0.0);
  FAnalyzer.SetVoltage(1, VPulse);
  SleepSeconds(AT);
  FAnalyzer.SetVoltage(1, 0.0);
end;

function TAnnealManager.Anneal(const AParams: TAnnealParameters; TaskID : String): TAnnealResult;
var
  Res                  : TAnnealResult;
  HWRes                : THardwareResult;
  ProbingParameters    : TProbingParameters;
  T0                   : Double;
  CurrentR             : Double;
  Cycle, Pair          : Integer;
  TotalPairs           : Integer;
  Stop                 : Boolean;
  TStart               : Double;
begin
  Res.TargetResistance := AParams.TargetResistance;
  T0 := NowSeconds;
  SetLength(ProbingParameters.VoltageList, 4);
  ProbingParameters.VoltageList[0] := -0.01;
  ProbingParameters.VoltageList[1] := -0.005;
  ProbingParameters.VoltageList[2] := 0.005;
  ProbingParameters.VoltageList[3] := 0.01;
  ProbingParameters.InitialWait:=0.5;
  ProbingParameters.MeasureTime:=0.5;
  FObserver.TaskStarted(TaskID);
  SendZeroVoltage();
  CurrentR := ProbeResistance(ProbingParameters,TaskID).MeanResistance;
  Res.AddResistanceSample(T0,CurrentR);
  FObserver.MeasurementPoint(T0,CurrentR,TaskID);
  { If initial R already exceeds target, skip the anneal loop }
  if (Res.FinalResistance >= AParams.TargetResistance) then
  begin
    FObserver.Log(Format('Initial R (%.1f Ohm) already exceeds target ' +
                   '(%.1f Ohm). Skipping anneal.',
                   [Res.FinalResistance, AParams.TargetResistance]),TaskID);
    Res.Finalise;
    Result  := Res;
    Exit;
  end;

  TotalPairs := 0;
  Stop       := False;

  for Cycle := 0 to Aparams.Cycles - 1 do
  begin
    { Inner loop: NPulsePairs pairs per cycle }
    for Pair := 0 to AParams.PulsePairs - 1 do
    begin
      { Positive pulse }
      try
        TStart := NowSeconds;
        AnnealPulse(AParams.PulsePositive, AParams.PulseLength);
        Res.AppendPulseDuration(NowSeconds - TStart);
      except
        on E: Exception do
        begin
          FObserver.Log(Format('Could not send positive pulse ' +
                         '(cycle %d, pair %d): %s. Stopping.',
                         [Cycle, Pair, E.Message]),TaskID);
          FObserver.Error(E.Message,TaskID);
          Stop := True;
          Break;
        end;
      end;

      { Negative pulse }
      try
        TStart := NowSeconds;
        AnnealPulse(AParams.PulseNegative, AParams.PulseLength);
        Res.AppendPulseDuration(NowSeconds - TStart);
      except
        on E: Exception do
        begin
          FObserver.Log(Format('Could not send negative pulse ' +
                         '(cycle %d, pair %d): %s. Stopping.',
                         [Cycle, Pair, E.Message]),TaskID);
          FObserver.Error(E.Message,TaskID);
          Stop := True;
          Break;
        end;
      end;

      Inc(TotalPairs);
    end;  { pair loop }

    if Stop then Break;

    { Resistance measurement after all pairs in this cycle }
    CurrentR := ProbeResistance(ProbingParameters,TaskID).MeanResistance;
    FObserver.MeasurementPoint(NowSeconds,CurrentR,TaskID);
    Res.AddResistanceSample(NowSeconds,CurrentR);
    FObserver.Log(Format('Cycle %d/%d  R = %.1f Ohm',
                   [Cycle + 1, Aparams.Cycles, CurrentR]),TaskID);

    { Early stop: target reached }
    if (CurrentR >= AParams.TargetResistance) then
    begin
      FObserver.Log(Format('[Target reached after %d cycles (%d pairs). ' +
                     'R = %.1f Ohm',
                     [Cycle + 1, TotalPairs, CurrentR]),TaskID);

       FObserver.MeasurementPoint(NowSeconds,CurrentR,TaskID);

      Break;
    end;

    { Early stop: junction damaged }
    if IsDamaged(CurrentR,AParams.ThresholdOpen,AParams.ThresholdShort) then
    begin
      FObserver.Log(Format('Junction appears damaged (R = %.1f Ohm). Stopping.',
                     [CurrentR]),TaskID);
      Break;
    end;
  end;  { cycle loop }

  FAnalyzer.DisableOutputs;
  Res.Finalise;
  { Free previous result if any, store new one }
  Result  := Res;
  HWRes.CommandType:=hcAnneal;
  HWRes.AnnealResult:=Result;
  FObserver.TaskFinished(HWRes,TaskID);
  FObserver.Log(Format('[Anneal complete. %d pulse pairs across %d cycles. ' +
                 'Final R = %.1f Ohm',
                 [TotalPairs,
                  Length(Res.ResistanceSamples) - 1,
                  Res.FinalResistance]),TaskID);
end;

function TAnnealManager.AnnealBatch(const ASpecs: TAnnealParameterArray;
                  TaskID : String): TAnnealResultArray;
var
  Coord           : TProberCoord;
  i               : Integer;
  BR              : TAnnealResult;
  HWRes           : THardwareResult;
begin
  SetLength(Result, 0);
  Coord := FProber.Start;
  FObserver.TaskStarted(TaskID);
  Fobserver.Log(Format('[AnnealBatch] Prober started at %s', [Coord.ToString]),TaskID);
  Fobserver.Log(Format('[AnnealBatch] %d junctions to process.', [Length(ASpecs)]),TaskID);

  for i := 0 to High(ASpecs) do
  begin
    Fobserver.Log(Format('--- [%d/%d] %s  coord=%s ---',
                   [i + 1, Length(ASpecs),
                    Coord.Subsite, Coord.ToString]),TaskID);

    BR := Anneal(ASpecs[i],TaskID);
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)].AnnealResult := BR;
    Result[High(Result)].Coord := Coord;

    { Advance prober (skip on last junction) }
    if i < High(ASpecs) then
    try
      Coord := FProber.NextSubsite;
      FObserver.Log(Format('[AnnealBatch] Prober moved to %s', [Coord.ToString]),TaskID);
    except
      on E: Exception do
      begin
        FObserver.Log('[AnnealBatch] Prober move failed: ' + E.Message +
                '. Stopping batch.',TaskID);
        Break;
      end;
    end;
  end;

  FProber.Finish;
  FObserver.Log('[AnnealBatch] Batch complete.',TaskID);
  HWRes.CommandType:=hcAnnealBatch;
  HWRes.AnnealResultArray:=Result;
  FObserver.TaskFinished(HWRes,TaskID);
end;

procedure TAnnealManager.SendZeroVoltage();

begin
  FAnalyzer.SetVoltage(1, 0.0);
  FAnalyzer.SetVoltage(2, 0.0);
end;

function TAnnealManager.ProbeBatch(AParams: TProbingParameters;
                  TaskID : String): TProbingResultArray;
var
  Coord : TProberCoord;
  i     : Integer;
  M     : TProbingResult;
  EndOfBatch : Boolean;
  HWRes           : THardwareResult;
begin
  SetLength(Result, 0);
  i:=0;
  EndOfBatch:=False;
  FObserver.TaskStarted(TaskID);
  Coord := FProber.Start;
  Fobserver.Log(Format('[ProbeBatch] Prober started at %s', [Coord.ToString]),TaskID);
  try
    while not Coord.Break do
    begin
      Fobserver.Log(Format('  [%d] %s ... ',
                   [i + 1, Coord.ToString]),TaskID);

      M := ProbeResistance(AParams,TaskID);
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)].ProbingResult := M;
      Result[High(Result)].Coord := Coord;
      try
        Coord := FProber.NextSubsite;
      except
        on E: Exception do
        begin
          WriteLn('[ProbeBatch] Prober move failed: ' + E.Message +
                  '. Stopping.');
          Break;
        end;
      end;
    end;
  finally
  end;

  FProber.Finish;
  Fobserver.Log(Format('[ProbeBatch] Done. %d junctions measured.',
                 [Length(Result)]),TaskID);
  HWRes.CommandType:=hcProbeBatch;
  HWRes.ProbingResultArray:=Result;
  FObserver.TaskFinished(HWRes,TaskID);

end;

procedure TAnnealManager.DisconnectAll;
begin
  if Assigned(FAnalyzer) then
  begin
    try FAnalyzer.Disconnect; except end;
    FreeAndNil(FAnalyzer);
  end;
  if Assigned(FHeater) then
  begin
    try FHeater.Disconnect; except end;
    FreeAndNil(FHeater);
  end;
  if Assigned(FProber) then
  begin
    try FProber.Disconnect; except end;
    FreeAndNil(FProber);
  end;
end;


end.

