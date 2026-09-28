unit TreeAssist;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils,AnnealTypes;
type
    TNodeType = (ntDevice, ntAddTask, ntAnneal, ntResistance, ntAnnealConfig,
               ntAnnealResult, ntResistanceConfig, ntResistanceResult);

    TDeviceNode = class
    public
      constructor Create;
    end;

    TProbeNode = class(TDeviceNode)
    public
      constructor Create;
      FProbingParameters : TProbingParameters;
      FProbingResult : TProbingResult;
    end;

    TAnnealNode = class(TDeviceNode)
    public
      constructor Create;
      FAnnealParameters: TAnnealParameters;
      FAnnealResult:     TAnnealResult;
    end;

    TProbeBatchNode = class(TDeviceNode)
    public
      constructor Create;
      FProbingParameters : TProbingParameters;
      FProbingResultArray : TProbingResultArray;
    end;

    TAnnelBatchNode = class(TDeviceNode)
    public
      constructor Create;
      FAnnealParameterArray: TAnnealParameterArray;
      FAnnealResultArray:     TAnnealResultArray;
    end;

implementation

end.

