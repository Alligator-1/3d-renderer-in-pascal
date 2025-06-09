unit soft3d_triangle;
{$mode objfpc}

//  Based on code taken from here:
//  https://github.com/michalzalobny/3d-renderer-in-c

interface

uses
  soft3d_texture, soft3d_vector, soft3d_display;

type
  PFace = ^TFace;
  TFace = record
    a: Int32;
    b: Int32;
    c: Int32;
    a_uv: TTex2;
    b_uv: TTex2;
    c_uv: TTex2;
    color: UInt32;
  end;

  PTriangle = ^TTriangle;
  TTriangle = record
    points: array [0..2] of TVec4;
    texcoords: array [0..2] of TTex2;
    color: UInt32;
  end;


function barycentric_weights(const a, b, c, p: TVec2): TVec3;
procedure draw_triangle(x0, y0, x1, y1, x2, y2: Int32; color: UInt32);
procedure draw_triangle_pixel(
    x, y: Int32; color: UInt32;
    const point_a, point_b, point_c: TVec4);
procedure draw_triangle_texel(
    x, y: Int32; texture: PUInt32;
    const point_a, point_b, point_c: TVec4;
    const a_uv, b_uv, c_uv: TTex2);
procedure draw_textured_triangle(
    x0, y0: Int32; z0, w0, u0, v0: Single;
    x1, y1: Int32; z1, w1, u1, v1: Single;
    x2, y2: Int32; z2, w2, u2, v2: Single;
    texture: PUInt32);
procedure draw_filled_triangle(
    x0, y0: Int32; z0, w0: Single;
    x1, y1: Int32; z1, w1: Single;
    x2, y2: Int32; z2, w2: Single;
    color: UInt32);

implementation

procedure int_swap(var a, b: Int32);
var
  tmp: Int32;
begin
  tmp := a;
  a := b;
  b := tmp;
end;

procedure float_swap(var a, b: Single);
var
  tmp: Single;
begin
  tmp := a;
  a := b;
  b := tmp;
end;


///////////////////////////////////////////////////////////////////////////////
// Return the barycentric weights alpha, beta, and gamma for point p
///////////////////////////////////////////////////////////////////////////////
//
//         (B)
//         /|\
//        / | \
//       /  |  \
//      /  (P)  \
//     /  /   \  \
//    / /       \ \
//   //           \\
//  (A)------------(C)
//
///////////////////////////////////////////////////////////////////////////////
function barycentric_weights(const a, b, c, p: TVec2): TVec3;
var
  ac, ab, ap, pc, pb: TVec2;
  area_parallelogram_abc, alpha, beta, gamma: Single;
begin
    // Find the vectors between the vertices ABC and point p
    ac := vec2_sub(c, a);
    ab := vec2_sub(b, a);
    ap := vec2_sub(p, a);
    pc := vec2_sub(c, p);
    pb := vec2_sub(b, p);

    // Compute the area of the full parallegram/triangle ABC using 2D cross product
    area_parallelogram_abc := (ac.x * ab.y - ac.y * ab.x); // || AC x AB ||

    // Alpha is the area of the small parallelogram/triangle PBC divided by the area of the full parallelogram/triangle ABC
    alpha := (pc.x * pb.y - pc.y * pb.x) / area_parallelogram_abc;

    // Beta is the area of the small parallelogram/triangle APC divided by the area of the full parallelogram/triangle ABC
    beta := (ac.x * ap.y - ac.y * ap.x) / area_parallelogram_abc;

    // Weight gamma is easily found since barycentric coordinates always add up to 1.0
    gamma := 1.0 - alpha - beta;

    Result.x := alpha;
    Result.y := beta;
    Result.z := gamma;
end;

///////////////////////////////////////////////////////////////////////////////
// Draw a triangle using three raw line calls
///////////////////////////////////////////////////////////////////////////////
procedure draw_triangle(x0, y0, x1, y1, x2, y2: Int32; color: UInt32);
begin
  draw_line(x0, y0, x1, y1, color);
  draw_line(x1, y1, x2, y2, color);
  draw_line(x2, y2, x0, y0, color);
end;

///////////////////////////////////////////////////////////////////////////////
// Function to draw a solid pixel at position (x,y) using depth interpolation
///////////////////////////////////////////////////////////////////////////////
procedure draw_triangle_pixel(
    x, y: Int32; color: UInt32;
    const point_a, point_b, point_c: TVec4);
var
  p, a, b, c: TVec2;
  weights: TVec3;
  alpha, beta, gamma: Single;
  interpolated_reciprocal_w: Single;
begin
    // Create three vec2 to find the interpolation
    p.x := x;
    p.y := y;
    a := vec2_from_vec4(point_a);
    b := vec2_from_vec4(point_b);
    c := vec2_from_vec4(point_c);

    // Calculate the barycentric coordinates of our point 'p' inside the triangle
    weights := barycentric_weights(a, b, c, p);

    alpha := weights.x;
    beta := weights.y;
    gamma := weights.z;

    // Interpolate the value of 1/w for the current pixel
    interpolated_reciprocal_w := (1.0 / point_a.w) * alpha + (1.0 / point_b.w) * beta + (1.0 / point_c.w) * gamma;

    // Adjust 1/w so the pixels that are closer to the camera have smaller values
    interpolated_reciprocal_w := 1.0 - interpolated_reciprocal_w;

    // Only draw the pixel if the depth value is less than the one previously stored in the z-buffer
    if interpolated_reciprocal_w < z_buffer[window_width * y + x] then
    begin
        // Draw a pixel at position (x,y) with a solid color
        draw_pixel(x, y, color);

        // Update the z-buffer value with the 1/w of this current pixel
        z_buffer[window_width * y + x] := interpolated_reciprocal_w;
    end;
end;

///////////////////////////////////////////////////////////////////////////////
// Function to draw the textured pixel at position (x,y) using depth interpolation
///////////////////////////////////////////////////////////////////////////////
procedure draw_triangle_texel(
    x, y: Int32; texture: PUInt32;
    const point_a, point_b, point_c: TVec4;
    const a_uv, b_uv, c_uv: TTex2);
var
  p, a, b, c: TVec2;
  weights: TVec3;
  alpha, beta, gamma: Single;
  // Variables to store the interpolated values of U, V, and also 1/w for the current pixel
  interpolated_u, interpolated_v, interpolated_reciprocal_w: Single;
  tex_x, tex_y: Int32;
begin
    p.x := x; { x, y };
    p.y := y; { x, y };
    a := vec2_from_vec4(point_a);
    b := vec2_from_vec4(point_b);
    c := vec2_from_vec4(point_c);

    // Calculate the barycentric coordinates of our point 'p' inside the triangle
    weights := barycentric_weights(a, b, c, p);

    alpha := weights.x;
    beta := weights.y;
    gamma := weights.z;

    // Perform the interpolation of all U/w and V/w values using barycentric weights and a factor of 1/w
    interpolated_u := (a_uv.u / point_a.w) * alpha + (b_uv.u / point_b.w) * beta + (c_uv.u / point_c.w) * gamma;
    interpolated_v := (a_uv.v / point_a.w) * alpha + (b_uv.v / point_b.w) * beta + (c_uv.v / point_c.w) * gamma;

    // Also interpolate the value of 1/w for the current pixel
    interpolated_reciprocal_w := (1 / point_a.w) * alpha + (1 / point_b.w) * beta + (1 / point_c.w) * gamma;

    // Now we can divide back both interpolated values by 1/w
    interpolated_u := interpolated_u / interpolated_reciprocal_w;
    interpolated_v := interpolated_v / interpolated_reciprocal_w;

    // Map the UV coordinate to the full texture width and height
    tex_x := Abs(Trunc(interpolated_u * texture_width)) mod texture_width;
    tex_y := Abs(Trunc(interpolated_v * texture_height)) mod texture_height;

    // Adjust 1/w so the pixels that are closer to the camera have smaller values
    interpolated_reciprocal_w := 1.0 - interpolated_reciprocal_w;

    // Only draw the pixel if the depth value is less than the one previously stored in the z-buffer
    if interpolated_reciprocal_w < z_buffer[window_width * y + x] then
    begin
        // Draw a pixel at position (x,y) with the color that comes from the mapped texture
        draw_pixel(x, y, texture[texture_width * tex_y + tex_x]);

        // Update the z-buffer value with the 1/w of this current pixel
        z_buffer[window_width * y + x] := interpolated_reciprocal_w;
    end;
end;

///////////////////////////////////////////////////////////////////////////////
// Draw a textured triangle based on a texture array of colors.
// We split the original triangle in two, half flat-bottom and half flat-top.
///////////////////////////////////////////////////////////////////////////////
//
//        v0
//        /\
//       /  \
//      /    \
//     /      \
//   v1--------\
//     \_       \
//        \_     \
//           \_   \
//              \_ \
//                 \\
//                   \
//                    v2
//
///////////////////////////////////////////////////////////////////////////////
procedure draw_textured_triangle(
    x0, y0: Int32; z0, w0, u0, v0: Single;
    x1, y1: Int32; z1, w1, u1, v1: Single;
    x2, y2: Int32; z2, w2, u2, v2: Single;
    texture: PUInt32);
var
  point_a, point_b, point_c: TVec4;
  a_uv, b_uv, c_uv: TTex2;
  inv_slope_1, inv_slope_2: Single;
  x, y: Int32;
  x_start, x_end: Int32;
begin
    // We need to sort the vertices by y-coordinate ascending (y0 < y1 < y2)
    if y0 > y1  then
    begin
        int_swap(y0, y1);
        int_swap(x0, x1);
        float_swap(z0, z1);
        float_swap(w0, w1);
        float_swap(u0, u1);
        float_swap(v0, v1);
    end;
    if y1 > y2 then
    begin
        int_swap(y1, y2);
        int_swap(x1, x2);
        float_swap(z1, z2);
        float_swap(w1, w2);
        float_swap(u1, u2);
        float_swap(v1, v2);
    end;
    if y0 > y1 then
    begin
        int_swap(y0, y1);
        int_swap(x0, x1);
        float_swap(z0, z1);
        float_swap(w0, w1);
        float_swap(u0, u1);
        float_swap(v0, v1);
    end;

    // Flip the V component to account for inverted UV-coordinates (V grows downwards)
    v0 := 1.0 - v0;
    v1 := 1.0 - v1;
    v2 := 1.0 - v2;

    // Create vector points and texture coords after we sort the vertices
    point_a.x := x0;
    point_a.y := y0;
    point_a.z := z0;
    point_a.w := w0;

    point_b.x := x1;
    point_b.y := y1;
    point_b.z := z1;
    point_b.w := w1;

    point_c.x := x2;
    point_c.y := y2;
    point_c.z := z2;
    point_c.w := w2;

    a_uv.u := u0;
    a_uv.v := v0;

    b_uv.u := u1;
    b_uv.v := v1;

    c_uv.u := u2;
    c_uv.v := v2;

    ///////////////////////////////////////////////////////
    // Render the upper part of the triangle (flat-bottom)
    ///////////////////////////////////////////////////////
    inv_slope_1 := 0.0;
    inv_slope_2 := 0.0;

    if (y1 - y0) <> 0 then inv_slope_1 := (x1 - x0) / Abs(y1 - y0);
    if (y2 - y0) <> 0 then inv_slope_2 := (x2 - x0) / Abs(y2 - y0);

    if (y1 - y0) <> 0 then
    begin
        for y := y0 to y1 do
        begin
            x_start := Trunc(x1 + (y - y1) * inv_slope_1);
            x_end := Trunc(x0 + (y - y0) * inv_slope_2);

            if x_end < x_start then
            begin
                int_swap(x_start, x_end); // swap if x_start is to the right of x_end
            end;

            for x := x_start to x_end-1 do
            begin
                // Draw our pixel with the color that comes from the texture
                draw_triangle_texel(x, y, texture, point_a, point_b, point_c, a_uv, b_uv, c_uv);
            end;
        end;
    end;

    ///////////////////////////////////////////////////////
    // Render the bottom part of the triangle (flat-top)
    ///////////////////////////////////////////////////////
    inv_slope_1 := 0.0;
    inv_slope_2 := 0.0;

    if (y2 - y1) <> 0 then inv_slope_1 := (x2 - x1) / Abs(y2 - y1);
    if (y2 - y0) <> 0 then inv_slope_2 := (x2 - x0) / Abs(y2 - y0);

    if (y2 - y1) <> 0 then
    begin
        for y := y1 to y2 do
        begin
            x_start := Trunc(x1 + (y - y1) * inv_slope_1);
            x_end := Trunc(x0 + (y - y0) * inv_slope_2);

            if x_end < x_start then
            begin
                int_swap(x_start, x_end); // swap if x_start is to the right of x_end
            end;

            for x := x_start to x_end-1 do
            begin
                // Draw our pixel with the color that comes from the texture
                draw_triangle_texel(x, y, texture, point_a, point_b, point_c, a_uv, b_uv, c_uv);
            end;
        end;
    end;
end;

///////////////////////////////////////////////////////////////////////////////
// Draw a filled triangle with the flat-top/flat-bottom method
// We split the original triangle in two, half flat-bottom and half flat-top
///////////////////////////////////////////////////////////////////////////////
//
//          (x0,y0)
//            / \
//           /   \
//          /     \
//         /       \
//        /         \
//   (x1,y1)---------\
//       \_           \
//          \_         \
//             \_       \
//                \_     \
//                   \    \
//                     \_  \
//                        \_\
//                           \
//                         (x2,y2)
//
///////////////////////////////////////////////////////////////////////////////
procedure draw_filled_triangle(
    x0, y0: Int32; z0, w0: Single;
    x1, y1: Int32; z1, w1: Single;
    x2, y2: Int32; z2, w2: Single;
    color: UInt32);
var
  point_a, point_b, point_c: TVec4;
  inv_slope_1, inv_slope_2: Single;
  x, y: Int32;
  x_start, x_end: Int32;
begin
    // We need to sort the vertices by y-coordinate ascending (y0 < y1 < y2)
    if y0 > y1 then
    begin
        int_swap(y0, y1);
        int_swap(x0, x1);
        float_swap(z0, z1);
        float_swap(w0, w1);
    end;
    if y1 > y2 then
    begin
        int_swap(y1, y2);
        int_swap(x1, x2);
        float_swap(z1, z2);
        float_swap(w1, w2);
    end;
    if y0 > y1 then
    begin
        int_swap(y0, y1);
        int_swap(x0, x1);
        float_swap(z0, z1);
        float_swap(w0, w1);
    end;

    // Create three vector points after we sort the vertices
    point_a.x := x0;
    point_a.y := y0;
    point_a.z := z0;
    point_a.w := w0;

    point_b.x := x1;
    point_b.y := y1;
    point_b.z := z1;
    point_b.w := w1;

    point_c.x := x2;
    point_c.y := y2;
    point_c.z := z2;
    point_c.w := w2;

    ///////////////////////////////////////////////////////
    // Render the upper part of the triangle (flat-bottom)
    ///////////////////////////////////////////////////////
    inv_slope_1 := 0.0;
    inv_slope_2 := 0.0;

    if (y1 - y0) <> 0 then inv_slope_1 := (x1 - x0) / Abs(y1 - y0);
    if (y2 - y0) <> 0 then inv_slope_2 := (x2 - x0) / Abs(y2 - y0);

    if (y1 - y0) <> 0 then
    begin
        for y := y0 to y1 do
        begin
            x_start := Trunc(x1 + (y - y1) * inv_slope_1);
            x_end := Trunc(x0 + (y - y0) * inv_slope_2);

            if x_end < x_start then
            begin
                int_swap(x_start, x_end); // swap if x_start is to the right of x_end
            end;

            for x := x_start to x_end-1 do
            begin
                // Draw our pixel with a solid color
                draw_triangle_pixel(x, y, color, point_a, point_b, point_c);
            end;
        end;
    end;

    ///////////////////////////////////////////////////////
    // Render the bottom part of the triangle (flat-top)
    ///////////////////////////////////////////////////////
    inv_slope_1 := 0.0;
    inv_slope_2 := 0.0;

    if (y2 - y1) <> 0 then inv_slope_1 := (x2 - x1) / Abs(y2 - y1);
    if (y2 - y0) <> 0 then inv_slope_2 := (x2 - x0) / Abs(y2 - y0);

    if (y2 - y1) <> 0 then
    begin
        for y := y1 to y2 do
        begin
            x_start := Trunc(x1 + (y - y1) * inv_slope_1);
            x_end := Trunc(x0 + (y - y0) * inv_slope_2);

            if x_end < x_start then
            begin
                int_swap(x_start, x_end); // swap if x_start is to the right of x_end
            end;

            for x := x_start to x_end-1 do
            begin
                // Draw our pixel with a solid color
                draw_triangle_pixel(x, y, color, point_a, point_b, point_c);
            end;
        end;
    end;
end;

end.

