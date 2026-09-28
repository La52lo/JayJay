unit MeasurementObserver;

{$mode ObjFPC}{$H+}
{$interfaces corba}

interface

uses
  Classes, SysUtils, AnnealTypes;
type

IMeasurementObserver = interface

procedure Log(
  const Msg: string;
  TaskID: string);

procedure Progress(
  Percent: Double;
  TaskID: string);

procedure MeasurementPoint(
  Time: Double;
  Value: Double;
  TaskID: string);

procedure TaskStarted(
  TaskID: string);

procedure TaskFinished(
  Result: THardwareResult
  TaskID: string);

procedure Error(
  const Msg: string;
  TaskID: string);
end;


implementation

end.

