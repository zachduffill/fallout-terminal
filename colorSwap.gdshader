shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest_mipmap;

void fragment() {
    vec4 original_color = texture(SCREEN_TEXTURE,SCREEN_UV);
    vec4 replacement_color = vec4(121.0/255.0, 1.0, 96.0/255.0, 1.0); // RGB: 121, 255, 96

	float distance = length(original_color.rgb - replacement_color.rgb);

    if (distance > 0.99) {
        COLOR = replacement_color;
    } else {
        COLOR = vec4(0,0,0,1); //vec4(0.039,0.2,0.051,1);
    }
}