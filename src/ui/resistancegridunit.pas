unit ResistanceGridUnit;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, DBGrids;

type

  { TTResistanceForm }

  TTResistanceForm = class(TForm)
    TResistanceGrid: TDBGrid;
  private

  public

  end;

var
  TResistanceForm: TTResistanceForm;

implementation

{$R *.lfm}

end.

