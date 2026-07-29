#version 320 es

// Aumenta la saturacion de toda la pantalla preservando el brillo.
//
// La directiva #version de arriba debe coincidir con la del vertex shader
// interno de Hyprland, o el enlazado falla con "all shaders must use same
// shading language version". En esta GPU (ES 3.2) el pase usa tex320.vert;
// en hardware que solo llegue a ES 3.0 habria que poner 300 es.
//
// SATURATION: 1.0 = sin cambios, >1.0 mas saturado, <1.0 hacia gris.
// 1.15 es sutil, 1.20 se nota, por encima de 1.35 empieza a "quemar"
// los rojos y los tonos de piel. Ajusta y recarga con:
//     hyprctl keyword decoration:screen_shader ~/.config/hypr/screen-shaders/vibrance.frag

precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;

layout(location = 0) out vec4 fragColor;

const float SATURATION = 1.28;

// Pesos de luminancia Rec. 709: mantienen el brillo percibido constante,
// asi solo cambia la pureza del color y no la exposicion de la imagen.
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void main() {
    vec4 color = texture(tex, v_texcoord);

    float luma = dot(color.rgb, LUMA);
    // Extrapolar alejandose del gris equivalente satura; interpolar hacia
    // el gris desatura. El clamp evita que los canales que se salen del
    // rango se envuelvan y produzcan artefactos de color.
    vec3 saturated = mix(vec3(luma), color.rgb, SATURATION);

    fragColor = vec4(clamp(saturated, 0.0, 1.0), color.a);
}
