unit uClient;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DB, Forms, Controls, Graphics, Dialogs,
  DBGrids, StdCtrls, ExtCtrls, fpjson, jsonparser, uApiDataModule;

type

  { TFrmClient }

    TFrmClient = class(TForm)
    DBGrid: TDBGrid;
    Memo: TMemo;
    panel: TPanel;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure MemDatasetBeforeDelete(DataSet: TDataSet);
    procedure MemDatasetBeforePost(DataSet: TDataSet);

  private
    FModifiedFields: TStringList;

    procedure LoadData;
    procedure BuildDatasetFields(AFirstObj: TJSONObject);
    procedure FillDatasetFromArray(AArray: TJSONArray);

    procedure FieldChange(Sender: TField);
    procedure SendJSON(const AUrl: string; const AMethod: string; const AJSON: string);
    procedure AddFieldToJSON(AJSON: TJSONObject; AField: TField);

    function GetRecordUrl: string;
  end;

var
  FrmClient: TFrmClient;

implementation

{$R *.lfm}

const
  BASE_URL = 'http://localhost:8080';
  RESOURCE_PATH = '/api/v1/items';

  RESOURCE_URL = BASE_URL + RESOURCE_PATH;
  KEY_FIELD = 'id';

  { TFrmClient }

procedure TFrmClient.FormCreate(Sender: TObject);
begin
  FModifiedFields := TStringList.Create;

  dmApi.DataSource.DataSet := dmApi.MemDataset;
  DBGrid.DataSource := dmApi.DataSource;

  dmApi.MemDataset.BeforePost := @MemDatasetBeforePost;
  dmApi.MemDataset.BeforeDelete := @MemDatasetBeforeDelete;

  LoadData;
end;

procedure TFrmClient.LoadData;
var
  JsonData: TJSONData;
  Arr: TJSONArray;
  JSONString: string;
begin
  FModifiedFields.Clear;

  Memo.Lines.Clear;
  Memo.Lines.Add('GET ' + RESOURCE_URL);

  try
    JSONString := dmApi.IdHTTP.Get(RESOURCE_URL);

    Memo.Lines.Add('');
    Memo.Lines.Add('----- RESPONSE -----');
    Memo.Lines.Add(JSONString);
  except
    on E: Exception do
    begin
      Memo.Lines.Add('');
      Memo.Lines.Add('----- ERROR -----');
      Memo.Lines.Add(E.ClassName + ': ' + E.Message);
      Exit;
    end;
  end;

  JsonData := GetJSON(JSONString);
  try
    if JsonData.JSONType <> jtArray then
    begin
      ShowMessage('The received JSON is not an array.');
      Exit;
    end;

    Arr := TJSONArray(JsonData);

    if Arr.Count = 0 then
    begin
      ShowMessage('Empty JSON array.');
      Exit;
    end;

    BuildDatasetFields(Arr.Objects[0]);
    FillDatasetFromArray(Arr);

    DBGrid.Columns.Clear;
    DBGrid.AutoFillColumns := True;

    if not dmApi.MemDataset.IsEmpty then
      dmApi.MemDataset.First;

  finally
    JsonData.Free;
  end;
end;

procedure TFrmClient.BuildDatasetFields(AFirstObj: TJSONObject);
var
  I: integer;
  FieldName: string;
  FieldValue: TJSONData;
begin
  dmApi.MemDataset.Close;
  dmApi.MemDataset.FieldDefs.Clear;

  for I := 0 to AFirstObj.Count - 1 do
  begin
    FieldName := AFirstObj.Names[I];
    FieldValue := AFirstObj.Items[I];

    if FieldValue.JSONType in [jtObject, jtArray] then
      Continue;

    case FieldValue.JSONType of
      jtNumber:
        dmApi.MemDataset.FieldDefs.Add(FieldName, ftInteger);

      jtString:
        dmApi.MemDataset.FieldDefs.Add(FieldName, ftString, 255);

      jtBoolean:
        dmApi.MemDataset.FieldDefs.Add(FieldName, ftBoolean);
    end;
  end;

  dmApi.MemDataset.CreateTable;
  dmApi.MemDataset.Open;
end;

procedure TFrmClient.FillDatasetFromArray(AArray: TJSONArray);
var
  I, J: integer;
  RowObj: TJSONObject;
  FieldName: string;
  FieldData: TJSONData;
begin
  dmApi.MemDataset.BeforePost := nil;
  dmApi.MemDataset.DisableControls;

  try
    for I := 0 to AArray.Count - 1 do
    begin
      RowObj := AArray.Objects[I];

      dmApi.MemDataset.Append;
      try
        for J := 0 to dmApi.MemDataset.Fields.Count - 1 do
        begin
          FieldName := dmApi.MemDataset.Fields[J].FieldName;
          FieldData := RowObj.Find(FieldName);

          if not Assigned(FieldData) then
            Continue;

          if FieldData.JSONType = jtNull then
            Continue;

          case FieldData.JSONType of
            jtNumber:
              dmApi.MemDataset.FieldByName(FieldName).AsInteger :=
                FieldData.AsInteger;

            jtString:
              dmApi.MemDataset.FieldByName(FieldName).AsString :=
                FieldData.AsString;

            jtBoolean:
              dmApi.MemDataset.FieldByName(FieldName).AsBoolean :=
                FieldData.AsBoolean;
          end;
        end;

        dmApi.MemDataset.Post;
      except
        dmApi.MemDataset.Cancel;
        raise;
      end;
    end;

  finally
    dmApi.MemDataset.BeforePost := @MemDatasetBeforePost;
    dmApi.MemDataset.EnableControls;
  end;

  for J := 0 to dmApi.MemDataset.Fields.Count - 1 do
    dmApi.MemDataset.Fields[J].OnChange := @FieldChange;
end;

procedure TFrmClient.SendJSON(const AUrl: string; const AMethod: string;
  const AJSON: string);
var
  S: TStringStream;
begin
  S := TStringStream.Create(AJSON);
  try
    dmApi.IdHTTP.Request.ContentType := 'application/json';
    dmApi.IdHTTP.Request.CharSet := 'utf-8';

    if AMethod = 'POST' then
      dmApi.IdHTTP.Post(AUrl, S)
    else if AMethod = 'PUT' then
      dmApi.IdHTTP.Put(AUrl, S);

  finally
    S.Free;
  end;
end;

procedure TFrmClient.AddFieldToJSON(AJSON: TJSONObject; AField: TField);
begin
  if AField.IsNull then
  begin
    AJSON.Add(AField.FieldName, TJSONNull.Create);
    Exit;
  end;

  case AField.DataType of
    ftInteger, ftSmallint, ftWord, ftAutoInc:
      AJSON.Add(AField.FieldName, AField.AsInteger);

    ftFloat, ftCurrency, ftBCD:
      AJSON.Add(AField.FieldName, AField.AsFloat);

    ftBoolean:
      AJSON.Add(AField.FieldName, AField.AsBoolean);

    else
      AJSON.Add(AField.FieldName, AField.AsString);
  end;
end;

function TFrmClient.GetRecordUrl: string;
begin
  Result :=
    RESOURCE_URL + '/' + dmApi.MemDataset.FieldByName(KEY_FIELD).AsString;
end;

procedure TFrmClient.FormDestroy(Sender: TObject);
begin
  FModifiedFields.Free;
end;

procedure TFrmClient.FieldChange(Sender: TField);
begin
  if FModifiedFields.IndexOf(Sender.FieldName) = -1 then
    FModifiedFields.Add(Sender.FieldName);
end;

procedure TFrmClient.MemDatasetBeforeDelete(DataSet: TDataSet);
begin
  dmApi.IdHTTP.Delete(GetRecordUrl);
end;


procedure TFrmClient.MemDatasetBeforePost(DataSet: TDataSet);
var
  I: integer;
  MyJSON: TJSONObject;
  Field: TField;
begin
  MyJSON := TJSONObject.Create;
  try
    if DataSet.State = dsInsert then
    begin
      for I := 0 to dmApi.MemDataset.Fields.Count - 1 do
      begin
        Field := dmApi.MemDataset.Fields[I];
        AddFieldToJSON(MyJSON, Field);
      end;

      Memo.Text := MyJSON.AsJSON;
      SendJSON(RESOURCE_URL, 'POST', MyJSON.AsJSON);
    end;

    if DataSet.State = dsEdit then
    begin
      for I := 0 to dmApi.MemDataset.Fields.Count - 1 do
      begin
        Field := dmApi.MemDataset.Fields[I];

        if FModifiedFields.IndexOf(Field.FieldName) <> -1 then
          AddFieldToJSON(MyJSON, Field);
      end;

      Memo.Text := MyJSON.AsJSON;
      SendJSON(GetRecordUrl, 'PUT', MyJSON.AsJSON);
    end;

    FModifiedFields.Clear;

  finally
    MyJSON.Free;
  end;
end;

end.

