unit logview;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls;

type
  TLogViewForm = class(TForm)
    Memo1: TMemo;
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  LogViewForm: TLogViewForm;

implementation

{$R *.dfm}



procedure TLogViewForm.FormShow(Sender: TObject);
var
  ExStyle: NativeInt;
  IsTopMost: Boolean;
begin
  // Query the Win32 extended window styles
  ExStyle := GetWindowLongPtr(Handle, GWL_EXSTYLE);

  // Check specifically for the WS_EX_TOPMOST flag
 { IsTopMost := (ExStyle and WS_EX_TOPMOST) <> 0;

  if IsTopMost then
    ShowMessage('Debug: WS_EX_TOPMOST is active! Hex: ' + IntToHex(ExStyle, 8))
  else
    ShowMessage('Debug: WS_EX_TOPMOST is NOT active. Hex: ' + IntToHex(ExStyle, 8)); }
end;

end.
