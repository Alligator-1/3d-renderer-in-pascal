unit soft3d_light;
{$mode objfpc}

//  Based on code taken from here:
//  https://github.com/michalzalobny/3d-renderer-in-c

interface

uses
  soft3d_vector;

type
  TLight = record
    direction: TVec3;
  end;

var
  light: TLight = (direction: (x:0; y:0; z:1)); // Main light of the app;

function light_apply_intensity(original_color: UInt32; percentage_factor: Single): UInt32;

implementation

function light_apply_intensity(original_color: UInt32; percentage_factor: Single): UInt32;
var
  a,r,g,b: UInt32;
begin
  if percentage_factor < 0.0 then percentage_factor := 0;
  if percentage_factor > 1.0 then percentage_factor := 1;

  a := (original_color and $FF000000);
  r := Trunc((original_color and $00FF0000) * percentage_factor);
  g := Trunc((original_color and $0000FF00) * percentage_factor);
  b := Trunc((original_color and $000000FF) * percentage_factor);

  Result := a or (r and $00FF0000) or (g and $0000FF00) or (b and $000000FF);
end;

end.

