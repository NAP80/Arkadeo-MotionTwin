package flash.display;

// flash.display.BlendMode : ENUM (comme l'extern flash) → le jeu peut écrire
// `s.blendMode = ADD` (constructeur non qualifié résolu par le type attendu).
// Le mapping vers PIXI.BLEND_MODES est fait au rendu.
enum BlendMode {
	NORMAL;
	LAYER;
	MULTIPLY;
	SCREEN;
	LIGHTEN;
	DARKEN;
	DIFFERENCE;
	ADD;
	SUBTRACT;
	INVERT;
	ALPHA;
	ERASE;
	OVERLAY;
	HARDLIGHT;
	SHADER;
}
