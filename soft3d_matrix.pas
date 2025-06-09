unit soft3d_matrix;
{$mode objfpc}

//  Based on code taken from here:
//  https://github.com/michalzalobny/3d-renderer-in-c

interface

uses
  Math, soft3d_vector;

type
  PMat4 = ^TMat4;
  TMat4 = record
    m: array [0..3, 0..3] of Single; // 4x4 matrix -> 4 rows and 4 columns
  end;


  function mat4_identity: TMat4;
  function mat4_mul_vec4(const m: TMat4; const v: TVec4): TVec4;
  function mat4_mul_mat4(const a, b: TMat4): TMat4;
  function mat4_make_scale(sx, sy, sz: Single): TMat4;
  function mat4_make_translation(tx, ty, tz: Single): TMat4;
  function mat4_make_rotation_x(angle: Single): TMat4;
  function mat4_make_rotation_y(angle: Single): TMat4;
  function mat4_make_rotation_z(angle: Single): TMat4;
  function mat4_mul_vec4_project(const mat_proj: TMat4; const v: TVec4): TVec4;
  function mat4_make_ortho(l, b, n, r, t, f: Single): TMat4;
  function mat4_make_perspective(n, f: Single): TMat4;
  function mat4_make_projection(fov, aspect_ratio, near, far: Single): TMat4;
  function mat4_make_perspective_old(fov, aspect, znear, zfar: Single): TMat4;
  function mat4_look_at(const eye, target, up: TVec3): TMat4;

implementation

function mat4_identity: TMat4;
begin
  // | 1 0 0 0 |
  // | 0 1 0 0 |
  // | 0 0 1 0 |
  // | 0 0 0 1 |
  Result.m[0,0] := 1.0;
  Result.m[0,1] := 0.0;
  Result.m[0,2] := 0.0;
  Result.m[0,3] := 0.0;
  Result.m[1,0] := 0.0;
  Result.m[1,1] := 1.0;
  Result.m[1,2] := 0.0;
  Result.m[1,3] := 0.0;
  Result.m[2,0] := 0.0;
  Result.m[2,1] := 0.0;
  Result.m[2,2] := 1.0;
  Result.m[2,3] := 0.0;
  Result.m[3,0] := 0.0;
  Result.m[3,1] := 0.0;
  Result.m[3,2] := 0.0;
  Result.m[3,3] := 1.0;
end;

function mat4_mul_vec4(const m: TMat4; const v: TVec4): TVec4;
begin
  // Example of this multiplication (values can be all different):
  // | sx 0 0 0 |   | x |   | x'|
  // | 0 sy 0 0 | X | y | = | y'|
  // | 0 0 sz 0 |   | z |   | z'|
  // | 0 0 0  1 |   | 1 |   | 1 |

  Result.x := m.m[0, 0] * v.x + m.m[0, 1] * v.y + m.m[0, 2] * v.z + m.m[0, 3] * v.w;
  Result.y := m.m[1, 0] * v.x + m.m[1, 1] * v.y + m.m[1, 2] * v.z + m.m[1, 3] * v.w;
  Result.z := m.m[2, 0] * v.x + m.m[2, 1] * v.y + m.m[2, 2] * v.z + m.m[2, 3] * v.w;
  Result.w := m.m[3, 0] * v.x + m.m[3, 1] * v.y + m.m[3, 2] * v.z + m.m[3, 3] * v.w;
end;

function mat4_mul_mat4(const a, b: TMat4): TMat4;
var
  i: NativeInt;
begin
  for i:=0 to 3 do
  begin
         //m.m[i][j] =  a.m[i][0] * b.m[0][j] + a.m[i][1] * b.m[1][j] + a.m[i][2] * b.m[2][j] + a.m[i][3] * b.m[3][j];

    Result.m[i][0] := a.m[i][0] * b.m[0][0] + a.m[i][1] * b.m[1][0] + a.m[i][2] * b.m[2][0] + a.m[i][3] * b.m[3][0];
    Result.m[i][1] := a.m[i][0] * b.m[0][1] + a.m[i][1] * b.m[1][1] + a.m[i][2] * b.m[2][1] + a.m[i][3] * b.m[3][1];
    Result.m[i][2] := a.m[i][0] * b.m[0][2] + a.m[i][1] * b.m[1][2] + a.m[i][2] * b.m[2][2] + a.m[i][3] * b.m[3][2];
    Result.m[i][3] := a.m[i][0] * b.m[0][3] + a.m[i][1] * b.m[1][3] + a.m[i][2] * b.m[2][3] + a.m[i][3] * b.m[3][3];
  end;
end;

function mat4_make_scale(sx, sy, sz: Single): TMat4;
begin
  // | sx 0 0 0 |
  // | 0 sy 0 0 |
  // | 0 0 sz 0 |
  // | 0 0 0 1 |

  Result := mat4_identity;

  Result.m[0, 0] := sx;
  Result.m[1, 1] := sy;
  Result.m[2, 2] := sz;
end;

function mat4_make_translation(tx, ty, tz: Single): TMat4;
begin
  // | 1 0 0 tx |
  // | 0 1 0 ty |
  // | 0 0 1 tz |
  // | 0 0 0  1 |

  Result := mat4_identity;

  Result.m[0, 3] := tx;
  Result.m[1, 3] := ty;
  Result.m[2, 3] := tz;
end;

function mat4_make_rotation_x(angle: Single): TMat4;
var
  c, s: Single;
begin
  c := Cos(angle);
  s := Sin(angle);
  // | 1  0  0  0 |
  // | 0  c -s  0 |
  // | 0  s  c  0 |
  // | 0  0  0  1 |
  Result := mat4_identity();
  Result.m[1, 1] := c;
  Result.m[1, 2] := -s;
  Result.m[2, 1] := s;
  Result.m[2, 2] := c;
end;

function mat4_make_rotation_y(angle: Single): TMat4;
var
  c, s: Single;
begin
  c := Cos(angle);
  s := Sin(angle);
  // |  c  0  s  0 |
  // |  0  1  0  0 |
  // | -s  0  c  0 |
  // |  0  0  0  1 |
  Result := mat4_identity();
  Result.m[0, 0] := c;
  Result.m[0, 2] := s;
  Result.m[2, 0] := -s;
  Result.m[2, 2] := c;
end;

function mat4_make_rotation_z(angle: Single): TMat4;
var
  c, s: Single;
begin
  c := Cos(angle);
  s := Sin(angle);
  // | c -s  0  0 |
  // | s  c  0  0 |
  // | 0  0  1  0 |
  // | 0  0  0  1 |
  Result := mat4_identity();
  Result.m[0, 0] := c;
  Result.m[0, 1] := -s;
  Result.m[1, 0] := s;
  Result.m[1, 1] := c;
end;

//https://www.youtube.com/watch?v=U0_ONQQ5ZNM - more explanation of this those matrices
//https://www.youtube.com/watch?v=vu1VNKHfzqQ here too - start with this one

function mat4_mul_vec4_project(const mat_proj: TMat4; const v: TVec4): TVec4;
begin
  // multiply the projection matrix by our original vector
  Result := mat4_mul_vec4(mat_proj, v);

  // perform perspective divide with original z-value that is now stored in w
  if result.w <> 0.0 then
  begin
    Result.x := Result.x / Result.w;
    Result.y := Result.y / Result.w;
    Result.z := Result.z / Result.w;
  end;
end;

// translate and scale projected vector to -1 to 1 range
function mat4_make_ortho(l, b, n, r, t, f: Single): TMat4;
var
  c_x, c_y, c_z: Single;
  width, height, depth: Single;
  trans, scale: TMat4;
begin
  // translate to origin and scale to -1 to 1 range -> width, height, depth should be 2

  // Coordinates of center of the provided cube are:
  c_x := (l + r) / 2.0;
  c_y := (b + t) / 2.0;
  c_z := (n + f) / 2.0;

  // To translate the cube to the origin, we need to subtract the center coordinates from each vertex
  // | 1 0 0 -c_x |
  // | 0 1 0 -c_y |
  // | 0 0 1 -c_z |
  // | 0 0 0    1 |
  trans := mat4_identity;
  trans.m[0, 3] := -c_x;
  trans.m[1, 3] := -c_y;
  trans.m[2, 3] := -c_z;

  // Current width, height, depth of the cube:
  width  := r - l;
  height := t - b;
  depth  := f - n;

  // To scale the cube to have width, height, depth of 2 (be from -1 to 1)
  // we need to multiply each vertex by 2/width, 2/height, 2/depth
  // | 2/width 0        0        0 |
  // | 0       2/height  0       0 |
  // | 0       0        2/depth  0 |
  // | 0       0        0        1 |

  scale := mat4_identity();
  scale.m[0, 0] := 2.0 / width;
  scale.m[1, 1] := 2.0 / height;
  scale.m[2, 2] := 2.0 / depth;

  // Now we need to combine the two matrices into one
  Result := mat4_mul_mat4(trans, scale);
end;

function mat4_make_perspective(n, f: Single): TMat4;
begin
  // | n  0       0     0 |
  // | 0  n       0     0 |
  // | 0  0   (f+n) (-fn) |
  // | 0  0       1     0 |

  FillChar(Result, SizeOf(Result), 0);

  Result.m[0, 0] := n;
  Result.m[1, 1] := n;
  Result.m[2, 2] := f + n;
  Result.m[2, 3] := -f * n;
  Result.m[3, 2] := 1.0;
end;

function mat4_make_projection(fov, aspect_ratio, near, far: Single): TMat4;
var
  r, t, f: Single;
  l, b, n: Single;
  t_ortho, t_perspective: TMat4;
begin
  // Orthographic matrix X Perspective matrix

  r := near * Tan(fov / 2.0) * aspect_ratio; // aspect_ratio = width / height
  t := near * Tan(fov / 2.0);
  f := far;

  l := -r;
  b := -t;
  n := near;

  t_ortho := mat4_make_ortho(l, b, n, r, t, f);
  t_perspective := mat4_make_perspective(near, far);

  Result := mat4_mul_mat4(t_ortho, t_perspective);
end;

function mat4_make_perspective_old(fov, aspect, znear, zfar: Single): TMat4;
begin
  // | (w/h)*1/tan(fov/2)             0              0                 0 |
  // |                  0  1/tan(fov/2)              0                 0 |
  // |                  0             0     zf/(zf-zn)  (-zf*zn)/(zf-zn) |
  // |                  0             0              1                 0 |
  FillChar(Result, SizeOf(Result), 0);

  Result.m[0, 0] := aspect * (1.0 / Tan(fov / 2.0));
  Result.m[1, 1] := 1.0 / Tan(fov / 2.0);
  Result.m[2, 2] := zfar / (zfar - znear);
  Result.m[2, 3] := (-zfar * znear) / (zfar - znear);
  Result.m[3, 2] := 1.0;
end;

function mat4_look_at(const eye, target, up: TVec3): TMat4;
var
  x,y,z: TVec3;
begin
    // Compute the forward (z), right (x), and up (y) vectors
    z := vec3_sub(target, eye);
    vec3_normalize(z);
    x := vec3_cross(up, z);
    vec3_normalize(x);
    y := vec3_cross(z, x);

    // | x.x   x.y   x.z  -dot(x,eye) |
    // | y.x   y.y   y.z  -dot(y,eye) |
    // | z.x   z.y   z.z  -dot(z,eye) |
    // |   0     0     0            1 |

    Result.m[0, 0] := x.x;
    Result.m[0, 1] := x.y;
    Result.m[0, 2] := x.z;
    Result.m[0, 3] := -vec3_dot(x, eye);
    Result.m[1, 0] := y.x;
    Result.m[1, 1] := y.y;
    Result.m[1, 2] := y.z;
    Result.m[1, 3] := -vec3_dot(y, eye);
    Result.m[2, 0] := z.x;
    Result.m[2, 1] := z.y;
    Result.m[2, 2] := z.z;
    Result.m[2, 3] := -vec3_dot(z, eye);
    Result.m[3, 0] := 0.0;
    Result.m[3, 1] := 0.0;
    Result.m[3, 2] := 0.0;
    Result.m[3, 3] := 1.0;
end;


end.

