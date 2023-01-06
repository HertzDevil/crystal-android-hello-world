#version 300 es

precision mediump float;

uniform float uContrast;

in vec4 vColor;

out vec4 fragColor;

float applyContrast(float value) {
  return clamp((value - 0.5) / (1.0 - uContrast) + 0.5, 0.0, 1.0);
}

void main() {
  fragColor = vec4(
    applyContrast(vColor.x),
    applyContrast(vColor.y),
    applyContrast(vColor.z),
    1.0
  );
}
