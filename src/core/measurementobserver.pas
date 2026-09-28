unit MeasurementObserver;

interface

uses
  Classes, SysUtils, AnnealTypes;
type

IMeasurementObserver = interface(IInterface)
['{62375512-E5F5-4F67-8C65-C6F9A984B630}']
procedure Log(
  const Msg: string);

procedure InitializeSetup(
  Status: TSetupStatus);

procedure MeasurementPoint(
  Time: Double;
  Value: Double);

procedure TaskStarted(
);

procedure TaskFinished(
  Result: THardwareResult);

procedure Error(
  const Msg: string);
end;


implementation

end.

