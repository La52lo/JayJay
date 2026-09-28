unit TaskSelectDialogUnit;

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  AnnealTypes;

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
    function ShowTaskSelectDialog(out ANodeType: TNodeType): Boolean;
  end;

var
  TaskSelectDialog: TTaskSelectDialog;

implementation

{$R *.dfm}

{ TTaskSelectDialog }

function TTaskSelectDialog.ShowTaskSelectDialog(out ANodeType: TNodeType): Boolean;
begin
  TaskSelectDialog.ShowModal;
  Result := modalResult = mrOk;
  if Result then
  begin
    if RadioButtonSingleAnneal.Checked then
      ANodeType := ntAnneal
    else if RadioButtonBatchAnneal.Checked then
      ANodeType := ntBatchAnneal
    else if RadioButtonSingleResistance.Checked then
      ANodeType := ntProbe
    else
      ANodeType := ntBatchProbe;
  end;
end;

end.
