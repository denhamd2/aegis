"""Put the source Info garment mask in glTF TEXCOORD_1 for Godot UV2.y.

The photographic atlas remains UV0. Existing optional UV layers are preserved
after the new mask channel; they are not assumed to contain garment data.
"""


def ensure_mask_uv(mesh):
    info = mesh.color_attributes['Info']
    assert info.domain == 'POINT'
    layers = mesh.uv_layers
    assert len(layers) >= 1
    original = [(layer.name, [tuple(loop.uv) for loop in layer.data])
                for layer in list(layers)[1:] if layer.name != 'SupporterGarmentMask']
    for layer in list(layers)[1:]:
        layers.remove(layer)
    mask = layers.new(name='SupporterGarmentMask', do_init=False)
    for loop in mesh.loops:
        # glTF reverses Blender's UV V. Store the complement here so Godot
        # receives UV2.y == Info.r on the exported mesh.
        mask.data[loop.index].uv = (0.5, 1.0 - info.data[loop.vertex_index].color[0])
    for name, values in original:
        layer = layers.new(name=name, do_init=False)
        for loop, uv in zip(layer.data, values):
            loop.uv = uv
    layers.active_index = 0
    layers[0].active_render = True
    assert layers[1].name == 'SupporterGarmentMask'
    return len(mesh.loops), len(original)
