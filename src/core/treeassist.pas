unit TreeAssist;


interface

uses
  Classes, SysUtils,AnnealTypes;
type
    TNodeType = (ntDevice, ntAddTask, ntAnneal, ntResistance, ntAnnealConfig,
               ntAnnealResult, ntResistanceConfig, ntResistanceResult);

    TDeviceNode = class
    public
    end;

    TProbeNode = class(TDeviceNode)
    public
      FProbingParameters : TProbingParameters;
      FProbingResult : TProbingResult;
    end;

    TAnnealNode = class(TDeviceNode)
    public
      FAnnealParameters: TAnnealConfig;
      FAnnealResult:     TAnnealResult;
    end;

    TProbeBatchNode = class(TDeviceNode)
    public
      FProbingParameters : TProbingParameters;
      FProbingResultArray : TProbingResultArray;
    end;

    TAnnelBatchNode = class(TDeviceNode)
    public
      FAnnealConfigArray: TAnnealConfigArray;
      FAnnealResultArray:     TAnnealResultArray;
    end;

implementation

end.

