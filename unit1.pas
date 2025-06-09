unit Unit1;
{$mode objfpc}{$H+}

//  Based on code taken from here:
//  https://github.com/michalzalobny/3d-renderer-in-c

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  LCLType, LCLIntf,  DelphiCompat,
  Math,
  soft3d_triangle, soft3d_texture, soft3d_vector,
  soft3d_matrix, soft3d_display, soft3d_camera,
  soft3d_clipping, soft3d_light,
  md5
  ;

type
  TMesh = record
    vertices:    array of TVec3; // Dynamic array of vertices
    faces:       array of TFace; // Dynamic array of faces
    faces_count: Int32;
    rotation:    TVec3; // rotation with x,y,z values (Euler angles)
    scale:       TVec3; // scale with x,y and z values
    translation: TVec3; // translation with x,y and z values
  end;

type

  { TForm1 }

  TForm1 = class(TForm)
    CheckGroup1: TCheckGroup;
    ComboBox1: TComboBox;
    Image1: TImage;
    Timer1: TTimer;
    procedure CheckGroup1ItemClick(Sender: TObject; Index: integer);
    procedure ComboBox1Change(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormResize(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure PaintMe;
    procedure UpdateCheckGroup;
  private
    model_name: String;
  public

  end;

var
  Form1: TForm1;

  mesh: TMesh = (
    vertices: nil;
    faces: nil;
    faces_count: 0;
    rotation:    (x: 0.0; y: 0.0; z: 0.0);
    scale:       (x: 1.0; y: 1.0; z: 1.0);
    translation: (x: 0.0; y: 0.0; z: 0.0);
  );


const
  // Array of triangles that should be rendere frame by frame
  MAX_TRIANGLES = 10000;

var
  triangles_to_render: array [0..MAX_TRIANGLES] of TTriangle;

  // Used to move away from the dynamic allocation of the triangles_to_render array
  num_triangles_to_render: Int32 = 0;

  proj_matrix: TMat4;
  view_matrix: TMat4;
  world_matrix: TMat4;

  is_running: Boolean = false;
  previous_frame_time: TDateTime = 0;
  delta_time: Single = 0.01;

  CULL_BACKFACE: Boolean = true;
  RENDER_WIREFRAME: Boolean = true;
  RENDER_FILL: Boolean = false;
  RENDER_VERTICES: Boolean = false;
  RENDER_TEXTURED: Boolean = true;

implementation
{$R *.lfm}

procedure load_obj_file_data(filename: String);
var
  f: Text;
  s: AnsiString;
  s2: string[2];
  s3: string[3];
  texcoords: array of TTex2;
  vertex_indices, texture_indices, normal_indices: array [0..2] of Int32;
begin
  AssignFile(f, filename);
  Reset(f);

  mesh.vertices := nil;
  mesh.faces := nil;

  while not EOF(f) do
  begin
    ReadLn(f, s);

    if s='' then Continue;

    // Vertex information
    if (s[1]='v') and (s[2]=' ') then
    begin
      SetLength(mesh.vertices, Length(mesh.vertices)+1);
      with mesh.vertices[High(mesh.vertices)] do
        ReadStr(s, s2, x, y, z);
    end
    // soft3d.texture coordinate information
    else if (s[1]='v') and (s[2]='t') and (s[3]=' ') then
    begin
      SetLength(texcoords, Length(texcoords)+1);
      with texcoords[High(texcoords)] do
        ReadStr(s, s3, u, v);
    end
    // Face information
    else if (s[1]='f') and (s[2]=' ') then
    begin
      ReadStr(s.Replace('/',' '), s2,
        vertex_indices[0], texture_indices[0], normal_indices[0],
        vertex_indices[1], texture_indices[1], normal_indices[1],
        vertex_indices[2], texture_indices[2], normal_indices[2]
      );

      SetLength(mesh.faces, Length(mesh.faces)+1);
      with mesh.faces[High(mesh.faces)] do
      begin
        a:=vertex_indices[0];
        b:=vertex_indices[1];
        c:=vertex_indices[2];
        a_uv:=texcoords[texture_indices[0]-1];
        b_uv:=texcoords[texture_indices[1]-1];
        c_uv:=texcoords[texture_indices[2]-1];
        color:=UInt32($FFFFFFFF);
      end;
    end;
  end;

  mesh.faces_count:=Length(mesh.faces);

  CloseFile(f);
end;


procedure setup_soft3d;
var
  aspect_y, aspect_x, fov_y, fov_x, z_near, z_far: Single;
begin
  // Allocate the required memory in bytes to hold the color buffer
  color_buffer := GetMem(SizeOf(UInt32) * window_width * window_height);
  z_buffer := GetMem(SizeOf(Single) * window_width * window_height);

  // Initialize the perspective projection matrix
  aspect_y := window_height / window_width;
  aspect_x := window_width / window_height;
  fov_y := Pi / 3.0; // the same as 180/3, or 60deg
  fov_x := ArcTan(Tan(fov_y / 2) * aspect_x) * 2;
  z_near := 1.0;
  z_far := 20.0;

  // Initialize frustum planes with a point and a normal
  init_frustum_planes(fov_x, fov_y, z_near, z_far);

  proj_matrix := mat4_make_projection(fov_y, aspect_x, z_near, z_far);

  // Load the cube values in the mesh data structure
  if FileExists('.\assets\'+Form1.model_name+'.obj') then
    load_obj_file_data('.\assets\'+Form1.model_name+'.obj');

  // Load the soft3d.texture information from an external PNG file
  if FileExists('.\assets\'+Form1.model_name+'.png') then
    mesh_texture := load_texture_data('.\assets\'+Form1.model_name+'.png', texture_width, texture_height)
  else
    mesh_texture := nil;
end;


procedure update_soft3d;
var
  target, up_direction: TVec3;
  camera_yaw_rotation: TMat4;
  scale_matrix: TMat4;
  rotation_matrix_x, rotation_matrix_y, rotation_matrix_z: TMat4;
  translation_matrix: TMat4;
  mesh_face: TFace;
  face_vertices, transformed_vertices: array [0..2] of TVec3;
  transformed_vertex: TVec4;
  vector_a, vector_b, vector_c: TVec3;
  vector_ab, vector_ac: TVec3;
  normal, origin: TVec3;
  camera_ray: TVec3;
  dot_normal_camera: Single;
  polygon: TPolygon;
  triangles_after_clipping: array [0..MAX_NUM_POLY_TRIANGLES-1] of TTriangle;
  num_triangles_after_clipping: Int32;
  triangle_after_clipping: TTriangle;
  projected_points: array [0..2] of TVec4;
  light_intensity_factor: Single;
  triangle_color: UInt32;
  triangle_to_render: TTriangle;
  i, j, t: NativeInt;
begin
  // Initialize the counter of triangles to render for the current frame
  num_triangles_to_render := 0;

  // Rotate the cube
  // mesh.rotation.x += 0.01 * delta_time;
  // mesh.rotation.y += 0.92 * delta_time;
  // mesh.rotation.z += 0.01 * delta_time;

  // mesh.scale.x = 0.5;
  // mesh.scale.y = 0.5;
  // mesh.scale.z = 0.5;
  mesh.translation.z := 5;
  // mesh.translation.y +=0.001;

  // Initialize the target looking at the positive z-axis
  target.x :=0.0;
  target.y :=0.0;
  target.z :=1.0;

  camera_yaw_rotation := mat4_make_rotation_y(camera.yaw);
  camera.direction := vec3_from_vec4(mat4_mul_vec4(camera_yaw_rotation, vec4_from_vec3(target)));

  // Offset the camera position in the direction where the camera is pointing at
  target := vec3_add(camera.position, camera.direction);
  up_direction.x := 0.0;
  up_direction.y := 1.0;
  up_direction.z := 0.0;

  // Create the view matrix
  view_matrix := mat4_look_at(camera.position, target, up_direction);

  // Create matrices that will be used to multiply mesh vertices
  scale_matrix := mat4_make_scale(mesh.scale.x, mesh.scale.y, mesh.scale.z);

  rotation_matrix_x := mat4_make_rotation_x(mesh.rotation.x);
  rotation_matrix_y := mat4_make_rotation_y(mesh.rotation.y);
  rotation_matrix_z := mat4_make_rotation_z(mesh.rotation.z);

  translation_matrix := mat4_make_translation(mesh.translation.x, mesh.translation.y, mesh.translation.z);

    // Loop all triangle faces of our mesh
    // int num_faces = array_length(mesh.faces);
    for i := 0 to mesh.faces_count-1 do
    begin
        mesh_face := mesh.faces[i];

        face_vertices[0] := mesh.vertices[mesh_face.a - 1];
        face_vertices[1] := mesh.vertices[mesh_face.b - 1];
        face_vertices[2] := mesh.vertices[mesh_face.c - 1];

        // Loop all three vertices of this current face and apply transformations
        for j := 0 to 2 do
        begin
            transformed_vertex := vec4_from_vec3(face_vertices[j]);

            // World Matrix combining scale, rotation and translation matrices
            world_matrix := mat4_identity();
            // Order matters. First scale, then rotate, and then translate. [T]*[R]*[S]*v
            world_matrix := mat4_mul_mat4(scale_matrix, world_matrix);
            world_matrix := mat4_mul_mat4(rotation_matrix_x, world_matrix);
            world_matrix := mat4_mul_mat4(rotation_matrix_y, world_matrix);
            world_matrix := mat4_mul_mat4(rotation_matrix_z, world_matrix);
            world_matrix := mat4_mul_mat4(translation_matrix, world_matrix);

            transformed_vertex := mat4_mul_vec4(world_matrix, transformed_vertex);

            // Multiply the view matrix by the vector to transform the scene to camera space
            transformed_vertex := mat4_mul_vec4(view_matrix, transformed_vertex);

            transformed_vertices[j] := vec3_from_vec4(transformed_vertex);
        end;

        // Check backface culling
        vector_a := transformed_vertices[0]; //*   A   */
        vector_b := transformed_vertices[1]; //*  / \  */
        vector_c := transformed_vertices[2]; //* C---B */

        // Get the  subtraction of B-A and C-A
        vector_ab := vec3_sub(vector_b, vector_a);
        vector_ac := vec3_sub(vector_c, vector_a);
        vec3_normalize(vector_ab);
        vec3_normalize(vector_ac);

        // Compute the face normal (using cross product to find perpendicular)
        normal := vec3_cross(vector_ab, vector_ac);
        vec3_normalize(normal);

        // Find the soft3d.vector between vertex A in the triangle and the camera origin
        origin.x := 0.0;
        origin.y := 0.0;
        origin.z := 0.0;
        camera_ray := vec3_sub(origin, vector_a);

        // How aligned the camera ray is with the face normal
        dot_normal_camera := vec3_dot(normal, camera_ray);

        if CULL_BACKFACE then
        begin
          // Don't render if not facing camera
          if dot_normal_camera < 0.0 then
          begin
            Continue;
          end;
        end;

        // Create a polygon from the original transformed triangle to be clipped
        polygon := polygon_from_triangle(
            transformed_vertices[0],
            transformed_vertices[1],
            transformed_vertices[2],
            mesh_face.a_uv,
            mesh_face.b_uv,
            mesh_face.c_uv
        );

        // Clip the polygon and returns a new polygon with potential new vertices
        clip_polygon(polygon);

        // Break the clipped polygon apart back into individual triangles
        num_triangles_after_clipping := 0;

        triangles_from_polygon(polygon, triangles_after_clipping, num_triangles_after_clipping);

        // Loops all the assembled triangles after soft3d.clipping
        for t := 0 to num_triangles_after_clipping-1 do
        begin
            triangle_after_clipping := triangles_after_clipping[t];

            // Loop all three vertices to perform projection and conversion to screen space
            for j := 0 to 2 do
            begin
                // Project the current vertex using a perspective projection matrix
                projected_points[j] := mat4_mul_vec4(proj_matrix, triangle_after_clipping.points[j]);

                // Perform perspective divide
                if projected_points[j].w <> 0.0 then
                begin
                  projected_points[j].x /= projected_points[j].w;
                  projected_points[j].y /= projected_points[j].w;
                  projected_points[j].z /= projected_points[j].w;
                end;

                // Flip vertically since the y values of the 3D mesh grow bottom->up and in screen space y values grow top->down
                projected_points[j].y *= -1;

                // Scale into the view
                projected_points[j].x *= (window_width / 2.0);
                projected_points[j].y *= (window_height / 2.0);

                // Translate the projected points to the middle of the screen
                projected_points[j].x += (window_width / 2.0);
                projected_points[j].y += (window_height / 2.0);
            end;

            // Calculate the shade intensity based on how aliged is the normal with the flipped light direction ray
            light_intensity_factor := -vec3_dot(normal, light.direction);

            // Calculate the triangle color based on the light angle
            triangle_color := light_apply_intensity(mesh_face.color, light_intensity_factor);

            // Create the final projected triangle that will be rendered in screen space
            triangle_to_render.points := projected_points;
            triangle_to_render.texcoords := triangle_after_clipping.texcoords;
            triangle_to_render.color := triangle_color;

            // Save the projected triangle in the array of triangles to render
            if (num_triangles_to_render < MAX_TRIANGLES) then
            begin
              triangles_to_render[num_triangles_to_render] := triangle_to_render;
              inc(num_triangles_to_render);
            end;
        end;

    end;
    // Sort the triangle to render by their avg_depth
end;


procedure render_soft3d;
var
  i: Int32;
  triangle: TTriangle;
  vw: Int32;
begin
  // draw_grid(0xFF0000FF, 15);

  // Fill background with gray color
  clear_color_buffer($FF999999);
  clear_z_buffer();

  // Loop all projected triangles and render them
  for i := 0 to num_triangles_to_render-1 do
  begin
    triangle := triangles_to_render[i];

    // Draw textured triangle
    if RENDER_TEXTURED then
    begin
      if mesh_texture<>nil then
       draw_textured_triangle(
          Trunc(triangle.points[0].x), Trunc(triangle.points[0].y), triangle.points[0].z, triangle.points[0].w, triangle.texcoords[0].u, triangle.texcoords[0].v, // vertex A
          Trunc(triangle.points[1].x), Trunc(triangle.points[1].y), triangle.points[1].z, triangle.points[1].w, triangle.texcoords[1].u, triangle.texcoords[1].v, // vertex B
          Trunc(triangle.points[2].x), Trunc(triangle.points[2].y), triangle.points[2].z, triangle.points[2].w, triangle.texcoords[2].u, triangle.texcoords[2].v, // vertex C
          mesh_texture);
    end;

    if RENDER_FILL then
    begin
      // Draw filled triangle
      draw_filled_triangle(
        Trunc(triangle.points[0].x), Trunc(triangle.points[0].y), triangle.points[0].z, triangle.points[0].w, // vertex A
        Trunc(triangle.points[1].x), Trunc(triangle.points[1].y), triangle.points[1].z, triangle.points[1].w, // vertex B
        Trunc(triangle.points[2].x), Trunc(triangle.points[2].y), triangle.points[2].z, triangle.points[2].w, // vertex C
        triangle.color
      );
    end;

    if RENDER_WIREFRAME then
    begin
      // Draw unfilled triangle
      draw_triangle(
        Trunc(triangle.points[0].x), Trunc(triangle.points[0].y),
        Trunc(triangle.points[1].x), Trunc(triangle.points[1].y),
        Trunc(triangle.points[2].x), Trunc(triangle.points[2].y),
        $FF000000
      );
    end;

    if RENDER_VERTICES then
    begin
      vw := 8; // vertex width
      //Draw vertex points
      draw_rect(Trunc(triangle.points[0].x - vw / 2.0), Trunc(triangle.points[0].y - vw / 2.0), vw, vw, $FFFFFF00);
      draw_rect(Trunc(triangle.points[1].x - vw / 2.0), Trunc(triangle.points[1].y - vw / 2.0), vw, vw, $FFFFFF00);
      draw_rect(Trunc(triangle.points[2].x - vw / 2.0), Trunc(triangle.points[2].y - vw / 2.0), vw, vw, $FFFFFF00);
    end;
  end;
end;


procedure TForm1.PaintMe;
var
  t: TDateTime;
  s: String;
  i: integer;
begin
  //window_width:=ClientWidth;
  //window_height:=ClientHeight;

  setup_soft3d;

  t:=Now;

  update_soft3d;
  render_soft3d;

  WriteStr(s, (Now-t)*MSecsPerDay:0:0);

  Image1.Picture.Bitmap.PixelFormat:=pf32bit;
  Image1.Picture.Bitmap.Width:=window_width;
  Image1.Picture.Bitmap.Height:=window_height;

  //if MD5Print(MD5Buffer(color_buffer^, Image1.Picture.Bitmap.RawImage.DataSize)) <> 'faeb5d7801dba7b062d5389a0dcb1501' then
  //  s+=', BAD DATA' else s+=', OK!';

  Image1.Picture.Bitmap.BeginUpdate();
  Move(color_buffer^, Image1.Picture.Bitmap.RawImage.Data^, Image1.Picture.Bitmap.RawImage.DataSize);
  Image1.Picture.Bitmap.EndUpdate();

  FreeMem(color_buffer);
  FreeMem(z_buffer);
  FreeMem(mesh_texture);

  Caption:=s;
end;

procedure TForm1.UpdateCheckGroup;
begin
  CheckGroup1.Checked[0] := CULL_BACKFACE;
  CheckGroup1.Checked[1] := RENDER_WIREFRAME;
  CheckGroup1.Checked[2] := RENDER_FILL;
  CheckGroup1.Checked[3] := RENDER_VERTICES;
  CheckGroup1.Checked[4] := RENDER_TEXTURED;
end;

procedure TForm1.CheckGroup1ItemClick(Sender: TObject; Index: integer);
begin
  CULL_BACKFACE    := CheckGroup1.Checked[0];
  RENDER_WIREFRAME := CheckGroup1.Checked[1];
  RENDER_FILL      := CheckGroup1.Checked[2];
  RENDER_VERTICES  := CheckGroup1.Checked[3];
  RENDER_TEXTURED  := CheckGroup1.Checked[4];

  if RENDER_TEXTURED and RENDER_FILL and (Index = 2) then
    RENDER_TEXTURED := FALSE;

  if RENDER_TEXTURED then
    RENDER_FILL := FALSE;

  UpdateCheckGroup;
end;

procedure TForm1.ComboBox1Change(Sender: TObject);
begin
  model_name:=ComboBox1.Caption;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);

  model_name := 'crab';

  UpdateCheckGroup;
end;

procedure TForm1.FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_1: CULL_BACKFACE := not CULL_BACKFACE;
    VK_2: RENDER_WIREFRAME := not RENDER_WIREFRAME;
    VK_3: RENDER_FILL := not RENDER_FILL;
    VK_4: RENDER_VERTICES := not RENDER_VERTICES;
    VK_5: RENDER_TEXTURED := not RENDER_TEXTURED;
  end;

  UpdateCheckGroup;
end;

procedure TForm1.FormResize(Sender: TObject);
begin

end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
  if GetKeyState(VK_UP)  <0 then camera.position.y += 3.0 * delta_time;
  if GetKeyState(VK_DOWN)<0 then camera.position.y -= 3.0 * delta_time;
  if GetKeyState(VK_A)   <0 then camera.yaw -= 1.0 * delta_time;
  if GetKeyState(VK_D)   <0 then camera.yaw += 1.0 * delta_time;
  if GetKeyState(VK_W)   <0 then
  begin
    camera.forward_velocity := vec3_mul(camera.direction, 5.0 * delta_time);
    camera.position := vec3_add(camera.position, camera.forward_velocity);
  end;
  if GetKeyState(VK_S)<0 then
  begin
    camera.forward_velocity := vec3_mul(camera.direction, 5.0 * delta_time);
    camera.position := vec3_sub(camera.position, camera.forward_velocity);
  end;

  PaintMe;
end;

end.

