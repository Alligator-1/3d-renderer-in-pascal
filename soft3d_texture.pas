unit soft3d_texture;
{$mode objfpc}{$h+}

//  Based on code taken from here:
//  https://github.com/michalzalobny/3d-renderer-in-c

interface

uses
  Graphics;

type
  PTex2 = ^TTex2;
  TTex2 = record
    u: Single;
    v: Single;
  end;

var
  mesh_texture: PUInt32;
  texture_width: Int32;
  texture_height: Int32;

function load_texture_data(filename: String; var _texture_width: Int32; var _texture_height: Int32): PUInt32;
function tex2_clone(const t: TTex2): TTex2;

implementation

function load_texture_data(filename: String; var _texture_width: Int32; var _texture_height: Int32): PUInt32;
var
  picTexture: TPicture;
begin
  picTexture :=TPicture.Create;
  picTexture.LoadFromFile(filename);

  _texture_width := picTexture.Width;
  _texture_height := picTexture.Height;

  Result:=GetMem(picTexture.Pixmap.RawImage.DataSize);
  Move(picTexture.Pixmap.RawImage.Data^, Result^, picTexture.Pixmap.RawImage.DataSize);

  picTexture.Free;
end;

function tex2_clone(const t: TTex2): TTex2;
begin
  Result.u := t.u;
  Result.v := t.v;
end;

end.

