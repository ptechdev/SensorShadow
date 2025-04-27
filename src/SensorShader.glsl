export default `
#define USE_NORMAL_SHADING

uniform float view_distance;
uniform vec3 viewArea_color;
uniform vec3 shadowArea_color;
uniform float percentShade;
uniform sampler2D colorTexture;
uniform sampler2D shadowMap;
uniform sampler2D depthTexture;
uniform mat4 shadowMap_matrix;
uniform vec3 viewPosition_WC;
uniform vec3 cameraPosition_WC;
uniform vec4 shadowMap_camera_positionEC;
uniform vec4 shadowMap_camera_directionEC;
uniform vec3 ellipsoidInverseRadii;
uniform vec3 shadowMap_camera_up;
uniform vec3 shadowMap_camera_dir;
uniform vec3 shadowMap_camera_right;
uniform vec4 shadowMap_normalOffsetScaleDistanceMaxDistanceAndDarkness;
uniform vec4 shadowMap_texelSizeDepthBiasAndNormalShadingSmooth;
uniform vec4 _shadowMap_cascadeSplits[2];
uniform mat4 _shadowMap_cascadeMatrices[4];
uniform vec4 _shadowMap_cascadeDistances;
uniform bool exclude_terrain;

in vec2 v_textureCoordinates;
out vec4 FragColor;

vec4 toEye(vec2 uv, float depth) {
    vec4 camPosition = czm_inverseProjection * vec4(uv * 2.0 - 1.0, depth, 1.0);
    camPosition /= camPosition.w;
    return camPosition;
}

float getDepth(vec4 depthTex) {
    float z_window = czm_reverseLogDepth(czm_unpackDepth(depthTex));
    return (2.0 * z_window - czm_depthRange.near - czm_depthRange.far) / (czm_depthRange.far - czm_depthRange.near);
}

void main() {
    vec4 color = texture(colorTexture, v_textureCoordinates);
    vec4 cDepth = texture(depthTexture, v_textureCoordinates);

    if (cDepth.r >= 1.0) {
        FragColor = color;
        return;
    }

    float depth = getDepth(cDepth);
    vec4 positionEC = toEye(v_textureCoordinates, depth);

    // Check if it's terrain and should be excluded
    if (exclude_terrain && czm_ellipsoidContainsPoint(ellipsoidInverseRadii, positionEC.xyz)) {
        FragColor = color;
        return;
    }

    // Check view distance
    vec4 lw = czm_inverseView * shadowMap_camera_positionEC;
    vec4 vw = czm_inverseView * vec4(positionEC.xyz, 1.0);
    
    if (distance(lw.xyz, vw.xyz) > view_distance) {
        FragColor = color;
        return;
    }

    // Shadow parameters setup
    czm_shadowParameters shadowParameters;
    shadowParameters.texelStepSize = shadowMap_texelSizeDepthBiasAndNormalShadingSmooth.xy;
    shadowParameters.depthBias = 0.00001;
    shadowParameters.normalShadingSmooth = shadowMap_texelSizeDepthBiasAndNormalShadingSmooth.w;
    shadowParameters.darkness = shadowMap_normalOffsetScaleDistanceMaxDistanceAndDarkness.w;

    vec3 directionEC = normalize(positionEC.xyz - shadowMap_camera_positionEC.xyz);
    float nDotL = clamp(dot(vec3(1.0), -directionEC), 0.0, 1.0);

    vec4 shadowPosition = shadowMap_matrix * positionEC;
    shadowPosition /= shadowPosition.w;

    if (any(lessThan(shadowPosition.xyz, vec3(0.0))) || any(greaterThan(shadowPosition.xyz, vec3(1.0)))) {
        FragColor = color;
        return;
    }

    // Apply shadow map lookup
    shadowParameters.texCoords = shadowPosition.xy;
    shadowParameters.depth = shadowPosition.z;
    shadowParameters.nDotL = nDotL;

    float visibility = czm_shadowVisibility(shadowMap, shadowParameters);

    if (visibility == 1.0) {
        FragColor = mix(color, vec4(viewArea_color, 1.0), percentShade);
    } else {
        if (abs(shadowPosition.z) < 0.01) {
            FragColor = color;
        } else {
            FragColor = mix(color, vec4(shadowArea_color, 1.0), percentShade);
        }
    }
}
`;
