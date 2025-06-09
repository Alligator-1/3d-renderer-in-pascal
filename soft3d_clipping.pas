unit soft3d_clipping;
{$mode objfpc}

//  Based on code taken from here:
//  https://github.com/michalzalobny/3d-renderer-in-c

interface

uses
  soft3d_vector, soft3d_texture, soft3d_triangle;

const
  MAX_NUM_POLY_VERTICES  = 10;
  MAX_NUM_POLY_TRIANGLES = 10;

type
  TFrustum_plane = (
    LEFT_FRUSTUM_PLANE,
    RIGHT_FRUSTUM_PLANE,
    TOP_FRUSTUM_PLANE,
    BOTTOM_FRUSTUM_PLANE,
    NEAR_FRUSTUM_PLANE,
    FAR_FRUSTUM_PLANE
  );

  PPlane = ^TPlane;
  TPlane = record
    point: TVec3;
    normal: TVec3;
  end;

  PPolygon = ^TPolygon;
  TPolygon = record
    vertices: array [0..MAX_NUM_POLY_VERTICES-1] of TVec3;
    texcoords: array [0..MAX_NUM_POLY_VERTICES-1] of TTex2;
    num_vertices: Int32;
  end;

var
  frustum_planes: array [TFrustum_plane] of TPlane;

procedure init_frustum_planes(fov_x, fov_y, z_near, z_far: Single);
function polygon_from_triangle(const v0, v1, v2: TVec3; const t0, t1, t2: TTex2): TPolygon;
procedure triangles_from_polygon(var polygon: TPolygon; triangles: PTriangle; var num_triangles: Int32);
function float_lerp(a, b, t: Single): Single;
procedure clip_polygon_against_plane(var polygon: TPolygon; plane: TFrustum_plane);
procedure clip_polygon(var polygon: TPolygon);


implementation

///////////////////////////////////////////////////////////////////////////////
// Frustum planes are defined by a point and a normal vector
///////////////////////////////////////////////////////////////////////////////
// Near plane   :  P=(0, 0, znear), N=(0, 0,  1)
// Far plane    :  P=(0, 0, zfar),  N=(0, 0, -1)
// Top plane    :  P=(0, 0, 0),     N=(0, -cos(fovy/2), sin(fovy/2))
// Bottom plane :  P=(0, 0, 0),     N=(0, cos(fovy/2), sin(fovy/2))
// Left plane   :  P=(0, 0, 0),     N=(cos(fovx/2), 0, sin(fovx/2))
// Right plane  :  P=(0, 0, 0),     N=(-cos(fovx/2), 0, sin(fovx/2))
///////////////////////////////////////////////////////////////////////////////
//
//           /|\
//         /  | |
//       /\   | |
//     /      | |
//  P*|-->  <-|*|   ----> +z-axis
//     \      | |
//       \/   | |
//         \  | |
//           \|/
//
///////////////////////////////////////////////////////////////////////////////
procedure init_frustum_planes(fov_x, fov_y, z_near, z_far: Single);
var
  cos_half_fov_x, sin_half_fov_x: Single;
  cos_half_fov_y, sin_half_fov_y: Single;
begin
  cos_half_fov_x := cos(fov_x / 2.0);
  sin_half_fov_x := sin(fov_x / 2.0);
  cos_half_fov_y := cos(fov_y / 2.0);
  sin_half_fov_y := sin(fov_y / 2.0);

  frustum_planes[LEFT_FRUSTUM_PLANE].point := vec3_new(0.0, 0.0, 0.0);
  frustum_planes[LEFT_FRUSTUM_PLANE].normal.x := cos_half_fov_x;
  frustum_planes[LEFT_FRUSTUM_PLANE].normal.y := 0.0;
  frustum_planes[LEFT_FRUSTUM_PLANE].normal.z := sin_half_fov_x;

  frustum_planes[RIGHT_FRUSTUM_PLANE].point := vec3_new(0.0, 0.0, 0.0);
  frustum_planes[RIGHT_FRUSTUM_PLANE].normal.x := -cos_half_fov_x;
  frustum_planes[RIGHT_FRUSTUM_PLANE].normal.y := 0.0;
  frustum_planes[RIGHT_FRUSTUM_PLANE].normal.z := sin_half_fov_x;

  frustum_planes[TOP_FRUSTUM_PLANE].point := vec3_new(0.0, 0.0, 0.0);
  frustum_planes[TOP_FRUSTUM_PLANE].normal.x := 0.0;
  frustum_planes[TOP_FRUSTUM_PLANE].normal.y := -cos_half_fov_y;
  frustum_planes[TOP_FRUSTUM_PLANE].normal.z := sin_half_fov_y;

  frustum_planes[BOTTOM_FRUSTUM_PLANE].point := vec3_new(0.0, 0.0, 0.0);
  frustum_planes[BOTTOM_FRUSTUM_PLANE].normal.x := 0.0;
  frustum_planes[BOTTOM_FRUSTUM_PLANE].normal.y := cos_half_fov_y;
  frustum_planes[BOTTOM_FRUSTUM_PLANE].normal.z := sin_half_fov_y;

  frustum_planes[NEAR_FRUSTUM_PLANE].point := vec3_new(0.0, 0.0, z_near);
  frustum_planes[NEAR_FRUSTUM_PLANE].normal.x := 0.0;
  frustum_planes[NEAR_FRUSTUM_PLANE].normal.y := 0.0;
  frustum_planes[NEAR_FRUSTUM_PLANE].normal.z := 1.0;

  frustum_planes[FAR_FRUSTUM_PLANE].point := vec3_new(0.0, 0.0, z_far);
  frustum_planes[FAR_FRUSTUM_PLANE].normal.x := 0.0;
  frustum_planes[FAR_FRUSTUM_PLANE].normal.y := 0.0;
  frustum_planes[FAR_FRUSTUM_PLANE].normal.z := -1.0;
end;

function polygon_from_triangle(const v0, v1, v2: TVec3; const t0, t1, t2: TTex2): TPolygon;
begin
  Result.vertices[0] := v0;
  Result.vertices[1] := v1;
  Result.vertices[2] := v2;

  Result.texcoords[0] := t0;
  Result.texcoords[1] := t1;
  Result.texcoords[2] := t2;

  Result.num_vertices := 3;
end;

procedure triangles_from_polygon(var polygon: TPolygon; triangles: PTriangle; var num_triangles: Int32);
var
  i, index0, index1, index2: Int32;
begin
    for i := 0 to polygon.num_vertices - 2 - 1 do
    begin
        index0 := 0;
        index1 := i + 1;
        index2 := i + 2;

        triangles[i].points[0] := vec4_from_vec3(polygon.vertices[index0]);
        triangles[i].points[1] := vec4_from_vec3(polygon.vertices[index1]);
        triangles[i].points[2] := vec4_from_vec3(polygon.vertices[index2]);

        triangles[i].texcoords[0] := polygon.texcoords[index0];
        triangles[i].texcoords[1] := polygon.texcoords[index1];
        triangles[i].texcoords[2] := polygon.texcoords[index2];
    end;
    num_triangles := polygon.num_vertices - 2;
end;

function float_lerp(a, b, t: Single): Single;
begin
  Result := a + t * (b - a);
end;

procedure clip_polygon_against_plane(var polygon: TPolygon; plane: TFrustum_plane);
var
  plane_point, plane_normal: TVec3;
  inside_vertices: array [0..MAX_NUM_POLY_VERTICES-1] of TVec3;
  inside_texcoords: array [0..MAX_NUM_POLY_VERTICES-1] of TTex2;
  num_inside_vertices: Int32;
  current_vertex: PVec3;
  current_texcoord: PTex2;
  previous_vertex: PVec3;
  previous_texcoord: PTex2;
  current_dot, previous_dot: Single;
  t: Single;
  intersection_point: TVec3;
  interpolated_texcoord: TTex2;
  i: Int32;
begin
    if polygon.num_vertices<= 0 then Exit;

    plane_point := frustum_planes[plane].point;
    plane_normal := frustum_planes[plane].normal;

    // Declare a static array of inside vertices that will be part of the final polygon returned via parameter
    num_inside_vertices := 0;

    // Start the current vertex with the first polygon vertex and texture coordinate
    current_vertex := @polygon.vertices[0];
    current_texcoord := @polygon.texcoords[0];

    // Start the previous vertex with the last polygon vertex and texture coordinate
    previous_vertex := @polygon.vertices[polygon.num_vertices - 1];
    previous_texcoord := @polygon.texcoords[polygon.num_vertices - 1];

    // Calculate the dot product of the current and previous vertex
    current_dot := 0.0;
    previous_dot := vec3_dot(vec3_sub(previous_vertex^, plane_point), plane_normal);

    // Loop all the polygon vertices while the current is different than the last one
    while current_vertex <> @polygon.vertices[polygon.num_vertices] do
    begin
        current_dot := vec3_dot(vec3_sub(current_vertex^, plane_point), plane_normal);

        // If we changed from inside to outside or from outside to inside
        if (current_dot * previous_dot < 0) then
        begin
            // Find the interpolation factor t
            t := previous_dot / (previous_dot - current_dot);

            // Calculate the intersection point I = Q1 + t(Q2-Q1)
            intersection_point.x := float_lerp(previous_vertex^.x, current_vertex^.x, t);
            intersection_point.y := float_lerp(previous_vertex^.y, current_vertex^.y, t);
            intersection_point.z := float_lerp(previous_vertex^.z, current_vertex^.z, t);

            // Use the lerp formula to get the interpolated U and V texture coordinates
            interpolated_texcoord.u := float_lerp(previous_texcoord^.u, current_texcoord^.u, t);
            interpolated_texcoord.v := float_lerp(previous_texcoord^.v, current_texcoord^.v, t);

            // Insert the intersection point to the list of "inside vertices"
            inside_vertices[num_inside_vertices] := intersection_point;
            inside_texcoords[num_inside_vertices] := interpolated_texcoord;

            Inc(num_inside_vertices);
        end;

        // Current vertex is inside the plane
        if (current_dot > 0) then
        begin
            // Insert the current vertex to the list of "inside vertices"
            inside_vertices[num_inside_vertices] := current_vertex^;
            inside_texcoords[num_inside_vertices] := current_texcoord^;
            Inc(num_inside_vertices);
        end;

        // Move to the next vertex
        previous_dot := current_dot;
        previous_vertex := current_vertex;
        previous_texcoord := current_texcoord;

        Inc(current_vertex);
        Inc(current_texcoord);
    end;

    // At the end, copy the list of inside vertices into the destination polygon (out parameter)
    for i := 0 to num_inside_vertices-1 do
    begin
        polygon.vertices[i] := inside_vertices[i];
        polygon.texcoords[i] := inside_texcoords[i];
    end;

    polygon.num_vertices := num_inside_vertices;
end;

procedure clip_polygon(var polygon: TPolygon);
begin
  clip_polygon_against_plane(polygon, LEFT_FRUSTUM_PLANE);
  clip_polygon_against_plane(polygon, RIGHT_FRUSTUM_PLANE);
  clip_polygon_against_plane(polygon, TOP_FRUSTUM_PLANE);
  clip_polygon_against_plane(polygon, BOTTOM_FRUSTUM_PLANE);
  clip_polygon_against_plane(polygon, NEAR_FRUSTUM_PLANE);
  clip_polygon_against_plane(polygon, FAR_FRUSTUM_PLANE);
end;


end.

