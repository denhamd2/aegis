extends SceneTree
func _initialize():
 var viewport=SubViewport.new();viewport.size=Vector2i(96,32);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var cam=Camera3D.new();cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=1;cam.position=Vector3(0,0,3);viewport.add_child(cam)
 for i in 3:
  var mesh=MeshInstance3D.new();mesh.mesh=QuadMesh.new();mesh.mesh.size=Vector2(.95,.95);mesh.position.x=i-1;viewport.add_child(mesh)
  var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  if i==0:mat.albedo_color=Color(.73,.65,.59)
  if i==1:
   var image=Image.create(1,1,false,Image.FORMAT_RGB8);image.fill(Color(.5,.5,.5));mat.albedo_texture=ImageTexture.create_from_image(image);mat.albedo_color=Color(.73,.65,.59)
  if i==2:mat.albedo_color=Color(.5,.5,.5)
  mesh.material_override=mat
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 var im=viewport.get_texture().get_image();im.save_png('/tmp/kenny-tint-check/actual.png')
 print('TINT_PIXELS ',im.get_pixel(16,16),' ',im.get_pixel(48,16),' ',im.get_pixel(80,16))
 quit()
