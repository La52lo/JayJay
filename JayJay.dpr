program JayJay;


uses
  Vcl.Forms,
  mainwindowunit in 'src\ui\mainwindowunit.pas' {MainWindowForm},
  threadinghelper in 'src\core\threadinghelper.pas',
  heatingstage in 'src\drivers\heatingstage.pas',
  prober in 'src\drivers\prober.pas',
  b1500constants in 'src\drivers\keysight_b1500a\b1500constants.pas',
  b1500mainframe in 'src\drivers\keysight_b1500a\b1500mainframe.pas',
  b1500module in 'src\drivers\keysight_b1500a\b1500module.pas',
  b1511b in 'src\drivers\keysight_b1500a\b1511b.pas',
  annealmanager in 'src\core\annealmanager.pas',
  annealtypes in 'src\core\annealtypes.pas',
  measurementobserver in 'src\core\measurementobserver.pas',
  treeassist in 'src\core\treeassist.pas',
  messagebuilder in 'src\core\messagebuilder.pas',
  visatransport in 'src\visa\visatransport.pas',
  devicedialogunit in 'src\ui\devicedialogunit.pas',
  resultviewer in 'src\ui\resultviewer.pas',
  probeconfig in 'src\ui\probeconfig.pas' {ProbeConfigForm},
  annealconfig in 'src\ui\annealconfig.pas' {AnnealConfigForm},
  devicemanagerunit in 'src\core\devicemanagerunit.pas',
  taskselectdialogunit in 'src\ui\taskselectdialogunit.pas' {TaskSelectDialog},
  logview in 'src\ui\logview.pas' {LogViewForm},
  nodejunctionmapper in 'src\core\nodejunctionmapper.pas';

{$R *.res}

begin

  Application.MainFormOnTaskbar:=False;
  Application.Initialize;
  Application.Title := 'JayJay';
  Application.CreateForm(TMainWindowForm, MainWindowForm);
  Application.CreateForm(TAnnealConfigForm, AnnealConfigForm);
  Application.CreateForm(TProbeConfigForm, ProbeConfigForm);
  Application.CreateForm(TLogViewForm, LogViewForm);
  Application.CreateForm(TTaskSelectDialog, TaskSelectDialog);
  Application.Run;
end.

