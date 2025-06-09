unit soft3d_vector;
{$mode objfpc}

//  Based on code taken from here:
//  https://github.com/michalzalobny/3d-renderer-in-c

interface

type
  PVec2 = ^TVec2;
  TVec2 = record
    x, y: Single;
  end;
  PVec3 = ^TVec3;
  TVec3 = record
    x, y, z: Single;
  end;
  PVec4 = ^TVec4;
  TVec4 = record
    x, y, z, w: Single;
  end;

  // Implementations of Vector 2D functions
  function vec2_length(const v: TVec2): Single;
  function vec2_add(const a, b: TVec2): TVec2;
  function vec2_sub(const a, b: TVec2): TVec2;
  function vec2_mul(const v: TVec2; factor: Single): TVec2;
  function vec2_div(const v: TVec2; factor: Single): TVec2;
  function vec2_dot(const a, b: TVec2): Single;
  procedure vec2_normalize(var v: TVec2);

  // Implementations of Vector 3D functions
  function vec3_length(const v: TVec3): Single;
  function vec3_add(const a, b: TVec3): TVec3;
  function vec3_sub(const a, b: TVec3): TVec3;
  function vec3_mul(const v: TVec3; factor: Single): TVec3;
  function vec3_div(const v: TVec3; factor: Single): TVec3;
  function vec3_cross(const a, b: TVec3): TVec3;
  function vec3_dot(const a, b: TVec3): Single;
  function vec3_rotate_x(const v: TVec3; angle: Single): TVec3;
  function vec3_rotate_y(const v: TVec3; angle: Single): TVec3;
  function vec3_rotate_z(const v: TVec3; angle: Single): TVec3;
  procedure vec3_normalize(var v: TVec3);

  // Vector conversion functions
  function vec4_from_vec3(const v: TVec3): TVec4;
  function vec3_from_vec4(const v: TVec4): TVec3;
  function vec2_from_vec4(const v: TVec4): TVec2;
  function vec3_new(x, y, z: Single): TVec3;
  function vec3_clone(const v: TVec3): TVec3;

implementation

// Implementations of Vector 2D functions

function vec2_length(const v: TVec2): Single;
begin
  Result := Sqrt(v.x * v.x + v.y * v.y);
end;

function vec2_add(const a, b: TVec2): TVec2;
begin
  Result.x:=a.x + b.x;
  Result.y:=a.y + b.y;
end;

function vec2_sub(const a, b: TVec2): TVec2;
begin
  Result.x:=a.x - b.x;
  Result.y:=a.y - b.y;
end;

function vec2_mul(const v: TVec2; factor: Single): TVec2;
begin
  Result.x := v.x * factor;
  Result.y := v.y * factor;
end;

function vec2_div(const v: TVec2; factor: Single): TVec2;
begin
  Result.x := v.x / factor;
  Result.y := v.y / factor;
end;

function vec2_dot(const a, b: TVec2): Single;
begin
  Result := a.x * b.x + a.y * b.y;
end;

procedure vec2_normalize(var v: TVec2);
var
  length: Single;
begin
  length := Sqrt(v.x * v.x + v.y * v.y);
  v.x := v.x / length;
  v.y := v.y / length;
end;


// Implementations of Vector 3D functions

function vec3_length(const v: TVec3): Single;
begin
  Result := Sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
end;

function vec3_add(const a, b: TVec3): TVec3;
begin
  Result.x := a.x + b.x;
  Result.y := a.y + b.y;
  Result.z := a.z + b.z;
end;

function vec3_sub(const a, b: TVec3): TVec3;
begin
  Result.x := a.x - b.x;
  Result.y := a.y - b.y;
  Result.z := a.z - b.z;
end;

function vec3_mul(const v: TVec3; factor: Single): TVec3;
begin
  Result.x := v.x * factor;
  Result.y := v.y * factor;
  Result.z := v.z * factor;
end;

function vec3_div(const v: TVec3; factor: Single): TVec3;
begin
  Result.x := v.x / factor;
  Result.y := v.y / factor;
  Result.z := v.z / factor;
end;

function vec3_cross(const a, b: TVec3): TVec3;
begin
  Result.x := a.y * b.z - a.z * b.y;
  Result.y := a.z * b.x - a.x * b.z;
  Result.z := a.x * b.y - a.y * b.x;
end;

function vec3_dot(const a, b: TVec3): Single;
begin
  Result := a.x * b.x + a.y * b.y + a.z * b.z;
end;

function vec3_rotate_x(const v: TVec3; angle: Single): TVec3;
begin
  Result.x := v.x;
  Result.y := v.y * Cos(angle) - v.z * Sin(angle);
  Result.z := v.y * Sin(angle) + v.z * Cos(angle);
end;

function vec3_rotate_y(const v: TVec3; angle: Single): TVec3;
begin
  Result.x := v.x * Cos(angle) - v.z * Sin(angle);
  Result.y := v.y;
  Result.z := v.x * Sin(angle) + v.z * Cos(angle);
end;

function vec3_rotate_z(const v: TVec3; angle: Single): TVec3;
begin
  Result.x := v.x * Cos(angle) - v.y * Sin(angle);
  Result.y := v.x * Sin(angle) + v.y * Cos(angle);
  Result.z := v.z;
end;

procedure vec3_normalize(var v: TVec3);
var
  length: Single;
begin
  length := Sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
  v.x := v.x / length;
  v.y := v.y / length;
  v.z := v.z / length;
end;


// Vector conversion functions

function vec4_from_vec3(const v: TVec3): TVec4;
begin
  Result.x := v.x;
  Result.y := v.y;
  Result.z := v.z;
  Result.w := 1.0;
end;

function vec3_from_vec4(const v: TVec4): TVec3;
begin
  Result.x := v.x;
  Result.y := v.y;
  Result.z := v.z;
end;

function vec2_from_vec4(const v: TVec4): TVec2;
begin
    Result.x := v.x;
    Result.y := v.y;
end;

function vec3_new(x, y, z: Single): TVec3;
begin
  Result.x := x;
  Result.y := y;
  Result.z := z;
end;

function vec3_clone(const v: TVec3): TVec3;
begin
  Result.x := v.x;
  Result.y := v.y;
  Result.z := v.z;
end;

end.

