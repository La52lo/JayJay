unit NodeJunctionMapper;

interface
uses
ComCtrls,System.Generics.Collections;
type
TTreeArrayMapper = class
  private
    FMap: TDictionary<TTreeNode, Integer>;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Add(ANode: TTreeNode; AIndex: Integer);
    function TryGetIndex(
      ANode: TTreeNode;
      out AIndex: Integer): Boolean;
end;

implementation
constructor TTreeArrayMapper.Create;
begin
  inherited;
  FMap := TDictionary<TTreeNode, Integer>.Create;
end;

destructor TTreeArrayMapper.Destroy;
begin
  FMap.Free;
  inherited;
end;

procedure TTreeArrayMapper.Add(
  ANode: TTreeNode;
  AIndex: Integer);
begin
  FMap.Add(ANode, AIndex);
end;

function TTreeArrayMapper.TryGetIndex(
  ANode: TTreeNode;
  out AIndex: Integer): Boolean;
begin
  Result := FMap.TryGetValue(ANode, AIndex);
end;

end.
