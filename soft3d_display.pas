unit soft3d_display;
{$mode objfpc}

//  Based on code taken from here:
//  https://github.com/michalzalobny/3d-renderer-in-c

interface

uses Math;

var
  color_buffer: PUInt32;
  z_buffer: PSingle;

  window_width: Int32 = 800;
  window_height: Int32 = 600;

procedure draw_grid(color: UInt32; gap_size: Int32);
procedure draw_pixel(x, y: Int32; color: UInt32);
procedure draw_rect(start_x, start_y, width, height: Int32; color: UInt32);
procedure clear_color_buffer(color: UInt32);
procedure clear_z_buffer;
procedure draw_line(x0, y0, x1, y1: Int32; color: UInt32);

implementation

function _roundf(value: Single): Single;
begin
  if value<0 then Result:=Ceil(value - 0.5) else Result:=Floor(value + 0.5);
end;

procedure draw_grid(color: UInt32; gap_size: Int32);
var
  x, y: Int32;
begin
   for y := 0 to window_height-1 do
   begin
    for x := 0 to window_width-1 do
    begin
      if ((x mod gap_size) <> 0) and ((y mod gap_size) <> 0) then Continue;
      color_buffer[window_width * y + x] := color;
    end;
   end;
end;

procedure draw_pixel(x, y: Int32; color: UInt32);
begin
  if (x>=0) and (x<window_width) and (y>=0) and (y<window_height) then
  begin
    color_buffer[window_width * y + x] := color;
  end;
end;

procedure draw_rect(start_x, start_y, width, height: Int32; color: UInt32);
var
  i, j: Int32;
  current_x, current_y: Int32;
begin
  for i := 0 to width-1 do
  begin
    for j := 0 to height-1 do
    begin
      current_x := start_x + i;
      current_y := start_y + j;
      draw_pixel(current_x, current_y, color);
    end;
  end;
end;


procedure clear_color_buffer(color: UInt32);
var
  x, y: Int32;
begin
  for y := 0 to window_height-1 do
  begin
    for x := 0 to window_width-1 do
    begin
      color_buffer[window_width * y + x] := color;
    end;
  end;
end;


procedure clear_z_buffer;
var
  x, y: Int32;
begin
  for y := 0 to window_height-1 do
  begin
    for x := 0 to window_width-1 do
    begin
      z_buffer[window_width * y + x] := 1.0;
    end;
  end;
end;

// Based on DDA algorithm: https://en.wikipedia.org/wiki/Digital_differential_analyzer_(graphics_algorithm)
procedure draw_line(x0, y0, x1, y1: Int32; color: UInt32);
var
  delta_x, delta_y: Int32;
  longest_side_length: Int32;
  x_inc, y_inc: Single;
  current_x, current_y: Single;
  i: Int32;
begin
  delta_x := (x1 - x0);
  delta_y := (y1 - y0);

  if Abs(delta_x) >= Abs(delta_y) then
    longest_side_length := Abs(delta_x)
  else
    longest_side_length := Abs(delta_y);

  // Find how much we should increment in both x and y each step
  x_inc := delta_x / longest_side_length; // Casting because we need float in the end, and C only reutnrs int when int/int
  y_inc := delta_y / longest_side_length;

  current_x := x0;
  current_y := y0;

  for i := 0 to longest_side_length do
  begin
    draw_pixel(Trunc(_roundf(current_x)), Trunc(_roundf(current_y)), color);
    current_x := current_x + x_inc;
    current_y := current_y + y_inc;
  end;
end;

end.

