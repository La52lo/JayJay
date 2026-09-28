unit DeviceDialogUnit;


interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls;

type

  { TDeviceDialog }

  TDeviceDialog = class(TForm)
    CancelButton: TButton;
    DeviceNameEdit: TEdit;
    Label1: TLabel;
    OKButton: TButton;
    Panel1: TPanel;
    procedure OKButtonClick(Sender: TObject);
  private
    FDeviceName: string;
  public
    function ShowDeviceDialog(out ADeviceName: string): Boolean;
  end;

var
  DeviceDialog: TDeviceDialog;

implementation

{$R *.dfm}

{ TDeviceDialog }

procedure TDeviceDialog.OKButtonClick(Sender: TObject);
begin
  if Trim(DeviceNameEdit.Text) = '' then
  begin
    ShowMessage('Please enter a device name.');
    Exit;
  end;
  FDeviceName := DeviceNameEdit.Text;
  ModalResult := mrOk;
end;

function TDeviceDialog.ShowDeviceDialog(out ADeviceName: string): Boolean;
begin
  DeviceNameEdit.Clear;
  DeviceNameEdit.SetFocus;
  Result := ShowModal = mrOk;
  if Result then
    ADeviceName := FDeviceName;
end;

end.
