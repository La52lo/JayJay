unit TaskSelectDialog;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls;

type

  TTaskType = (ttSingleAnneal, ttBatchAnneal, ttSingleResistance, ttBatchResistance);

  { TTaskSelectDialog }

  TTaskSelectDialog = class(TForm)
    CancelButton: TButton;
    OKButton: TButton;
    Panel1: TPanel;
    RadioButtonSingleAnneal: TRadioButton;
    RadioButtonBatchAnneal: TRadioButton;
    RadioButtonSingleResistance: TRadioButton;
    RadioButtonBatchResistance: TRadioButton;
  private
    FSelectedTask: TTaskType;
  public
    function ShowTaskSelectDialog(out ATaskType: TTaskType): Boolean;
  end;

var
  TaskSelectDialog: TTaskSelectDialog;

implementation

{$R *.lfm}

{ TTaskSelectDialog }

function TTaskSelectDialog.ShowTaskSelectDialog(out ATaskType: TTaskType): Boolean;
begin
  Result := ShowModal = mrOk;
  if Result then
  begin
    if RadioButtonSingleAnneal.Checked then
      ATaskType := ttSingleAnneal
    else if RadioButtonBatchAnneal.Checked then
      ATaskType := ttBatchAnneal
    else if RadioButtonSingleResistance.Checked then
      ATaskType := ttSingleResistance
    else
      ATaskType := ttBatchResistance;
  end;
end;

end.
