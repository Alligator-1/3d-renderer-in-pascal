unit soft3d_camera;
{$mode objfpc}

//  Based on code taken from here:
//  https://github.com/michalzalobny/3d-renderer-in-c

interface

uses
  soft3d_vector;

type
  PCamera = ^TCamera;
  TCamera = record
    position: TVec3;
    direction: TVec3;
    forward_velocity: TVec3;
    yaw: Single;
  end;

var
  camera: TCamera = (
    position: (x:0; y:0; z:0);
    direction: (x:0; y:0; z:1);
    forward_velocity: (x: 0; y:0; z:0);
    yaw: 0;
  );

implementation

end.

