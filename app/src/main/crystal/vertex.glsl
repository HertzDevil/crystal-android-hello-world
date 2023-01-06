#version 300 es

uniform mat4 uModelMatrix;
uniform mat4 uViewMatrix;
uniform mat4 uPerspectiveMatrix;
uniform vec3 uDiffuseLightDirection;
uniform vec3 uDiffuseLightColor;

in vec3 vPosition;
in vec3 vNormal;

out vec4 vColor;

void main() {
  gl_Position = uPerspectiveMatrix * uViewMatrix * uModelMatrix * vec4(vPosition, 1.0);

  vec3 worldNormal = normalize(mat3(uModelMatrix) * vNormal);
  float diffuseIntensity = clamp(dot(worldNormal, normalize(uDiffuseLightDirection)), 0.0, 1.0);
  vec3 intensity = diffuseIntensity * uDiffuseLightColor;
  vColor = vec4(intensity, 1.0);
}
