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

vec4 toEye(in vec2 uv, in float depth) {
    float x = uv.x * 2.0 - 1.0;
    float y = uv.y * 2.0 - 1.0;
    vec4 camPosition = czm_inverseProjection * vec4(x, y, depth, 1.0);
    camPosition /= camPosition.w;
    return camPosition;
}

float getDepth(in vec4 depth) {
    float z_window = czm_unpackDepth(depth);
    z_window = czm_reverseLogDepth(z_window);
    float n_range = czm_depthRange.near;
    float f_range = czm_depthRange.far;
    return (2.0 * z_window - n_range - f_range) / (f_range - n_range);
}

void main() 
{ 
    vec4 color = texture(colorTexture, v_textureCoordinates);
    vec4 cDepth = texture(depthTexture, v_textureCoordinates);

    if (cDepth.r >= 1.0) {
        FragColor = color;
        return;
    }

    float depth = getDepth(cDepth);
    vec4 positionEC = toEye(v_textureCoordinates, depth);

    if (
        cDepth.r >= 1.0 ||
        (exclude_terrain && czm_ellipsoidContainsPoint(ellipsoidInverseRadii, positionEC.xyz))
    ) {
        FragColor = color;
        return;
    }

    czm_shadowParameters shadowParameters;
    shadowParameters.texelStepSize = shadowMap_texelSizeDepthBiasAndNormalShadingSmooth.xy;
    shadowParameters.depthBias = shadowMap_texelSizeDepthBiasAndNormalShadingSmooth.z;
    shadowParameters.normalShadingSmooth = shadowMap_texelSizeDepthBiasAndNormalShadingSmooth.w;
    shadowParameters.darkness = shadowMap_normalOffsetScaleDistanceMaxDistanceAndDarkness.w;

    shadowParameters.depthBias *= max(depth * 0.01, 1.0);

    vec3 directionEC = normalize(positionEC.xyz - shadowMap_camera_positionEC.xyz);
    float nDotL = clamp(dot(vec3(1.0), -directionEC), 0.0, 1.0);

    vec4 shadowPosition = shadowMap_matrix * positionEC;
    shadowPosition /= shadowPosition.w;

    if (any(lessThan(shadowPosition.xyz, vec3(0.0))) || any(greaterThan(shadowPosition.xyz, vec3(1.0)))) {
        FragColor = color;
        return;
    }

    vec4 vw = czm_inverseView * vec4(positionEC.xyz, 1.0);
    float fragDistance = distance(viewPosition_WC.xyz, vw.xyz);

    if (fragDistance > view_distance) {
        FragColor = color;
        return;
    }

    shadowParameters.texCoords = shadowPosition.xy;
    shadowParameters.depth = shadowPosition.z;
    shadowParameters.nDotL = nDotL;

    float visibility = czm_shadowVisibility(shadowMap, shadowParameters);

    if (visibility > 0.99) { 
        FragColor = mix(color, vec4(viewArea_color, 1.0), percentShade);
    } else {
        if (abs(shadowPosition.z - 0.0) < 0.01) {
            FragColor = color;
            return;
        }
        FragColor = mix(color, vec4(shadowArea_color, 1.0), percentShade);
    }
}
`;
