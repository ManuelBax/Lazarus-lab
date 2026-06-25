unit urest;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fphttpserver, fpjson, jsonparser;

type

  { TDemoRestServer }

  TDemoRestServer = class
  private
    FServer: TFPHTTPServer;

    procedure HandleRequest(Sender: TObject; var ARequest: TFPHTTPConnectionRequest;
      var AResponse: TFPHTTPConnectionResponse);

    procedure RouteRequest(var ARequest: TFPHTTPConnectionRequest;
      var AResponse: TFPHTTPConnectionResponse);

    procedure WriteJSON(var AResponse: TFPHTTPConnectionResponse;
      ACode: integer; const AJSON: string);

    procedure WriteError(var AResponse: TFPHTTPConnectionResponse;
      ACode: integer; const AMessage: string);

    function MatchRoute(const AMethod, AURI, AExpectedMethod,
      AExpectedURI: string): boolean;

    procedure GetItems(var AResponse: TFPHTTPConnectionResponse);
    procedure GetItemById(const AId: integer;
      var AResponse: TFPHTTPConnectionResponse);
    procedure CreateItem(var ARequest: TFPHTTPConnectionRequest;
      var AResponse: TFPHTTPConnectionResponse);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Start;
    procedure Stop;
  end;

implementation

constructor TDemoRestServer.Create;
begin
  inherited Create;

  FServer := TFPHTTPServer.Create(nil);
  FServer.Port := 8080;
  FServer.Threaded := False;
  FServer.OnRequest := @HandleRequest;
end;

destructor TDemoRestServer.Destroy;
begin
  Stop;
  FServer.Free;
  inherited Destroy;
end;

procedure TDemoRestServer.Start;
begin
  FServer.Active := True;
end;

procedure TDemoRestServer.Stop;
begin
  FServer.Active := False;
end;

procedure TDemoRestServer.WriteJSON(var AResponse: TFPHTTPConnectionResponse;
  ACode: integer; const AJSON: string);
begin
  AResponse.Code := ACode;
  AResponse.ContentType := 'application/json; charset=utf-8';
  AResponse.Content := AJSON;
end;

procedure TDemoRestServer.WriteError(var AResponse: TFPHTTPConnectionResponse;
  ACode: integer; const AMessage: string);
var
  Obj: TJSONObject;
begin
  Obj := TJSONObject.Create;
  try
    Obj.Add('error', AMessage);
    WriteJSON(AResponse, ACode, Obj.AsJSON);
  finally
    Obj.Free;
  end;
end;

function TDemoRestServer.MatchRoute(
  const AMethod, AURI, AExpectedMethod, AExpectedURI: string): boolean;
begin
  Result :=
    SameText(AMethod, AExpectedMethod) and SameText(AURI, AExpectedURI);
end;

procedure TDemoRestServer.HandleRequest(Sender: TObject;
  var ARequest: TFPHTTPConnectionRequest; var AResponse: TFPHTTPConnectionResponse);
begin
  try
    RouteRequest(ARequest, AResponse);
  except
    on E: Exception do
      WriteError(AResponse, 500, E.Message);
  end;
end;

procedure TDemoRestServer.RouteRequest(var ARequest: TFPHTTPConnectionRequest;
  var AResponse: TFPHTTPConnectionResponse);
var
  Parts: TStringArray;
  IdItem: integer;
begin
  if MatchRoute(ARequest.Method, ARequest.URI, 'GET', '/api/v1/items') then
  begin
    GetItems(AResponse);
    Exit;
  end;

  if MatchRoute(ARequest.Method, ARequest.URI, 'POST', '/api/v1/items') then
  begin
    CreateItem(ARequest, AResponse);
    Exit;
  end;

  Parts := ARequest.URI.Split('/');

  // Ex: /api/v1/items/1
  if (Length(Parts) = 5) and SameText(Parts[1], 'api') and
    SameText(Parts[2], 'v1') and SameText(Parts[3], 'items') then
  begin
    IdItem := StrToIntDef(Parts[4], 0);

    if IdItem <= 0 then
    begin
      WriteError(AResponse, 400, 'invalid item id');
      Exit;
    end;

    if SameText(ARequest.Method, 'GET') then
    begin
      GetItemById(IdItem, AResponse);
      Exit;
    end;
  end;

  WriteError(AResponse, 404, 'endpoint not found');
end;

procedure TDemoRestServer.GetItems(var AResponse: TFPHTTPConnectionResponse);
begin
  WriteJSON(AResponse, 200,
    '[{"id":1,"name":"Sample item","description":"Demo record"}]');
end;

procedure TDemoRestServer.GetItemById(const AId: integer;
  var AResponse: TFPHTTPConnectionResponse);
var
  Obj: TJSONObject;
begin
  Obj := TJSONObject.Create;
  try
    Obj.Add('id', AId);
    Obj.Add('name', 'Sample item');
    Obj.Add('description', 'Demo item detail');

    WriteJSON(AResponse, 200, Obj.AsJSON);
  finally
    Obj.Free;
  end;
end;

procedure TDemoRestServer.CreateItem(var ARequest: TFPHTTPConnectionRequest;
  var AResponse: TFPHTTPConnectionResponse);
var
  Data: TJSONData;
  Obj: TJSONObject;
  Name: string;
begin
  Data := GetJSON(ARequest.Content);
  try
    if Data.JSONType <> jtObject then
    begin
      WriteError(AResponse, 400, 'invalid JSON');
      Exit;
    end;

    Obj := TJSONObject(Data);
    Name := Obj.Get('name', '');

    if Trim(Name) = '' then
    begin
      WriteError(AResponse, 400, 'name is required');
      Exit;
    end;

    WriteJSON(AResponse, 201,
      '{"message":"item created successfully"}');

  finally
    Data.Free;
  end;
end;

end.
