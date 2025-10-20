/**
 * Post-Process Shader Examples
 * 
 * Use these in Renderer.hx by replacing the fragment shader in initializePostProcessing()
 */

// =============================================================================
// 1. PASSTHROUGH (Default - No Effect)
// =============================================================================
var passthroughFrag = '
	#version 330 core
	in vec2 TexCoord;
	out vec4 FragColor;
	uniform sampler2D uScreenTexture;
	
	void main() {
		FragColor = texture(uScreenTexture, TexCoord);
	}
';

// =============================================================================
// 2. GRAYSCALE
// =============================================================================
var grayscaleFrag = '
	#version 330 core
	in vec2 TexCoord;
	out vec4 FragColor;
	uniform sampler2D uScreenTexture;
	
	void main() {
		vec4 color = texture(uScreenTexture, TexCoord);
		float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
		FragColor = vec4(vec3(gray), color.a);
	}
';

// =============================================================================
// 3. INVERT COLORS
// =============================================================================
var invertFrag = '
	#version 330 core
	in vec2 TexCoord;
	out vec4 FragColor;
	uniform sampler2D uScreenTexture;
	
	void main() {
		vec4 color = texture(uScreenTexture, TexCoord);
		FragColor = vec4(1.0 - color.rgb, color.a);
	}
';

// =============================================================================
// 4. SEPIA
// =============================================================================
var sepiaFrag = '
	#version 330 core
	in vec2 TexCoord;
	out vec4 FragColor;
	uniform sampler2D uScreenTexture;
	
	void main() {
		vec4 color = texture(uScreenTexture, TexCoord);
		vec3 sepia;
		sepia.r = dot(color.rgb, vec3(0.393, 0.769, 0.189));
		sepia.g = dot(color.rgb, vec3(0.349, 0.686, 0.168));
		sepia.b = dot(color.rgb, vec3(0.272, 0.534, 0.131));
		FragColor = vec4(sepia, color.a);
	}
';

// =============================================================================
// 5. CRT SCANLINES
// =============================================================================
var crtFrag = '
	#version 330 core
	in vec2 TexCoord;
	out vec4 FragColor;
	uniform sampler2D uScreenTexture;
	
	void main() {
		vec4 color = texture(uScreenTexture, TexCoord);
		
		// Scanline effect
		float scanline = sin(TexCoord.y * 480.0 * 2.0) * 0.1 + 0.9;
		
		// Vignette effect
		vec2 center = TexCoord - 0.5;
		float vignette = 1.0 - dot(center, center) * 0.5;
		
		FragColor = vec4(color.rgb * scanline * vignette, color.a);
	}
';

// =============================================================================
// 6. PIXELATION
// =============================================================================
var pixelateFrag = '
	#version 330 core
	in vec2 TexCoord;
	out vec4 FragColor;
	uniform sampler2D uScreenTexture;
	
	void main() {
		float pixelSize = 4.0;
		vec2 pixelated = floor(TexCoord * vec2(640.0, 480.0) / pixelSize) * pixelSize / vec2(640.0, 480.0);
		FragColor = texture(uScreenTexture, pixelated);
	}
';

// =============================================================================
// 7. EDGE DETECTION
// =============================================================================
var edgeFrag = '
	#version 330 core
	in vec2 TexCoord;
	out vec4 FragColor;
	uniform sampler2D uScreenTexture;
	
	void main() {
		vec2 texelSize = 1.0 / vec2(640.0, 480.0);
		
		// Sobel operator
		float edge = 0.0;
		edge += texture(uScreenTexture, TexCoord + vec2(-texelSize.x, -texelSize.y)).r;
		edge += texture(uScreenTexture, TexCoord + vec2(0.0, -texelSize.y)).r * 2.0;
		edge += texture(uScreenTexture, TexCoord + vec2(texelSize.x, -texelSize.y)).r;
		edge -= texture(uScreenTexture, TexCoord + vec2(-texelSize.x, texelSize.y)).r;
		edge -= texture(uScreenTexture, TexCoord + vec2(0.0, texelSize.y)).r * 2.0;
		edge -= texture(uScreenTexture, TexCoord + vec2(texelSize.x, texelSize.y)).r;
		
		FragColor = vec4(vec3(edge), 1.0);
	}
';

// =============================================================================
// 8. CHROMATIC ABERRATION
// =============================================================================
var chromaticFrag = '
	#version 330 core
	in vec2 TexCoord;
	out vec4 FragColor;
	uniform sampler2D uScreenTexture;
	
	void main() {
		vec2 offset = (TexCoord - 0.5) * 0.01;
		
		float r = texture(uScreenTexture, TexCoord + offset).r;
		float g = texture(uScreenTexture, TexCoord).g;
		float b = texture(uScreenTexture, TexCoord - offset).b;
		
		FragColor = vec4(r, g, b, 1.0);
	}
';

// =============================================================================
// 9. BLOOM (Simple)
// =============================================================================
var bloomFrag = '
	#version 330 core
	in vec2 TexCoord;
	out vec4 FragColor;
	uniform sampler2D uScreenTexture;
	
	void main() {
		vec2 texelSize = 1.0 / vec2(640.0, 480.0);
		vec4 color = texture(uScreenTexture, TexCoord);
		
		// Simple blur for bloom
		vec4 bloom = vec4(0.0);
		for (int x = -2; x <= 2; x++) {
			for (int y = -2; y <= 2; y++) {
				bloom += texture(uScreenTexture, TexCoord + vec2(x, y) * texelSize * 2.0);
			}
		}
		bloom /= 25.0;
		
		// Add bloom to original
		FragColor = color + bloom * 0.3;
	}
';

// =============================================================================
// 10. VIGNETTE
// =============================================================================
var vignetteFrag = '
	#version 330 core
	in vec2 TexCoord;
	out vec4 FragColor;
	uniform sampler2D uScreenTexture;
	
	void main() {
		vec4 color = texture(uScreenTexture, TexCoord);
		
		vec2 center = TexCoord - 0.5;
		float vignette = 1.0 - dot(center, center) * 1.0;
		vignette = smoothstep(0.0, 1.0, vignette);
		
		FragColor = vec4(color.rgb * vignette, color.a);
	}
';
