unit uApiDataModule;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, IdHTTP, DB, memds;

type

  { TDataModule }

  TApiDataModule  = class(TDataModule)
    DataSource: TDataSource;
    IdHTTP: TIdHTTP;
    MemDataset: TMemDataset;
  private

  public

  end;

var
  dmApi: TApiDataModule;

implementation

{$R *.lfm}

end.

