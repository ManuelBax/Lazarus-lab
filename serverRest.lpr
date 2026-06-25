program serverRest;

{$mode objfpc}{$H+}

uses
  Classes,
  SysUtils,
  urest;

var
  Server: TDemoRestServer;

begin
  Server := TDemoRestServer.Create;
  try
    Server.Start;

    WriteLn('Demo REST server running');
    WriteLn('http://localhost:8080/api/v1/items');
    WriteLn('Press ENTER to stop...');
    ReadLn;
  finally
    Server.Free;
  end;
end.
