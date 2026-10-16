unit Unit2;

interface

implementation
procedure TDeviceManager.LoadDevice(const AFilePath: string);
var
  LJSON: TJSONObject;
  LTasksJSON: TJSONArray;
  LTaskJSON: TJSONValue;
  LTaskTypeJSON: TJSONValue;
  LTaskType: TNodeType;
  LTask: THardwareTask;
begin
  LJSON := TJSONObject.ParseJSONValue(
    TFile.ReadAllText(AFilePath)) as TJSONObject;

  if LJSON = nil then
    raise Exception.Create('Invalid device JSON');

  try
    // Deserialize the non-polymorphic properties.
    // Exclude Tasks from this pass, or deserialize them separately.
    // See the note below about Neon member configuration.

    LTasksJSON := LJSON.GetValue<TJSONArray>('Tasks');
    if LTasksJSON = nil then
      Exit;

    FTasks.Clear;

    for LTaskJSON in LTasksJSON do
    begin
      if not (LTaskJSON is TJSONObject) then
        Continue;

      LTaskTypeJSON := TJSONObject(LTaskJSON).GetValue('TaskType');
      if LTaskTypeJSON = nil then
        raise Exception.Create('TaskType is missing');

      LTaskType := TNodeType(GetEnumValue(
        TypeInfo(TNodeType), LTaskTypeJSON.Value));

      case LTaskType of
        ntAnneal:
          LTask := TAnnealTask.Create('', LTaskType);

        ntProbe:
          LTask := TProbeTask.Create('', LTaskType);

      else
        raise Exception.CreateFmt(
          'Unsupported task type: %s',
          [LTaskTypeJSON.Value]);
      end;

      try
        TNeon.JSONToObject(LTask, TJSONObject(LTaskJSON));
        FTasks.Add(LTask);
      except
        LTask.Free;
        raise;
      end;
    end;
  finally
    LJSON.Free;
  end;
end;
end.

Neon provides SetIgnoreMembers / AddIgnoreMembers to exclude named members globally, and [NeonIgnore] to exclude a member with an attribute.

GitHub
+1

For your case, I recommend the attribute, if you can change TDeviceManager:

delphi
uses
  Neon.Core.Attributes;

type
  TDeviceManager = class
  private
    FTasks: TObjectList<THardwareTask>;
  public
    [NeonIgnore]
    property Tasks: TObjectList<THardwareTask>
      read FTasks write FTasks;
  end;
This excludes Tasks from both serialization and deserialization. You can then load the Tasks array manually using the factory approach we discussed.

Important: if your Neon configuration serializes fields rather than properties, the attribute on the property may not exclude the backing field FTasks. In that case, configure Neon to use properties:

delphi
Config := TNeonConfiguration.Default
  .SetMembers(TNeonMembers.Properties);
Alternatively, use AddIgnoreMembers / SetIgnoreMembers with the member name Tasks if you prefer configuration-based exclusion. The exact overload depends on your Neon version.
