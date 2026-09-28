unit JunctionManager;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, Classes, Math, StrUtils,
  B1500Mainframe,   { B1500 Parameter Analyzer driver }
  B1500Constants,   { B1500 Parameter Analyzer driver }
  HeatingStage,     { Heating Stage driver unit }
  Prober,           { Prober driver unit }
  b1511b,           { B1500 SMU }
  MeasurementObserver; {class to receive measurement points}

const
  DEFAULT_ANALYZER_ADDRESS = 'GPIB0::16::INSTR';
  DEFAULT_HEATER_ADDRESS   = 'GPIB0::7::INSTR';
  DEFAULT_PROBER_DIR       =
    'C:\Users\B1500\Documents\voltage_annealing\apollowave';
  DEFAULT_COMPLIANCE       = 0.05;   { 50 mA }
type
  TJunctionManager = class
  private
    FB1500      : TB1500Controller;
    FProber     : TProberController;
    FHeater     : THeatingStage;
    FObserver   : IMeasurementObserver;

  public

    constructor Create(
      const AnalyzerAddress : string;
      const HeaterAddress   : string;
      const ProberDirectory : string;
      Observer              : IMeasurementObserver);

    destructor Destroy; override;
    function Initialize : Boolean;
    procedure Shutdown;
    function ProbeResistance(): TProbeResult;
    function Anneal(const Spec : TJunctionSpec) : TAnnealResult;
    function AnnealBatch(const Specs : TJunctionSpecArray) : TAnnealResultArray;
    function ProbeBatch(Count : Integer) : TProbeResultArray;
  end;
implementation

end.

