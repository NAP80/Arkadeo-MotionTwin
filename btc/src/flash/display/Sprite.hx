package flash.display;

// flash.display.Sprite adossé à PIXI.Container : tout objet de rendu en hérite.
// On ajoute les alias Flash attendus par les sources (scaleX/scaleY, graphics,
// blendMode, mouse*). Les filtres sont hérités (filters:Array<Filter>) et nos
// flash.filters.* étendent PIXI.Filter → `s.filters = [new GlowFilter(...)]` type-check.
class Sprite extends pixi.core.display.Container {
	var _graphics:Graphics;

	// blendMode Flash (enum) → PIXI.BLEND_MODES (Int). Un Container n'a pas de blend
	// propre : on le propage aux feuilles rendues (Sprite=texture, Graphics=geometry) du sous-arbre.
	var _blend:BlendMode = BlendMode.NORMAL;
	var _blendInt:Int = 0;
	public var blendMode(get, set):BlendMode;
	inline function get_blendMode():BlendMode return _blend;
	function set_blendMode(v:BlendMode):BlendMode {
		_blend = v;
		_blendInt = toPixiBlend(v);
		applyBlend(this, _blendInt);
		return v;
	}

	static function toPixiBlend(v:BlendMode):Int {
		return switch (v) {
			case ADD: js.Syntax.code("PIXI.BLEND_MODES.ADD");
			case MULTIPLY: js.Syntax.code("PIXI.BLEND_MODES.MULTIPLY");
			case SCREEN: js.Syntax.code("PIXI.BLEND_MODES.SCREEN");
			// OVERLAY non supporté par le renderer WebGL v5 (retombe NORMAL) → remappé SCREEN
			// (vraie équation, éclaircit), approximation la plus proche.
			case OVERLAY: js.Syntax.code("PIXI.BLEND_MODES.SCREEN");
			default: js.Syntax.code("PIXI.BLEND_MODES.NORMAL");
		}
	}

	static function applyBlend(o:Dynamic, b:Int):Void {
		untyped {
			if (o.texture != null || o.geometry != null)
				o.blendMode = b; // feuille Sprite (texture) ou Graphics (geometry)
			// La sortie d'un filtre se compose avec le blend DU filtre, sinon dessinée
			// en NORMAL (additif perdu) → propager aussi aux filtres.
			if (o.filters != null)
				for (f in (o.filters : Array<Dynamic>))
					f.blendMode = b;
			if (o.children != null)
				for (c in (o.children : Array<Dynamic>))
					applyBlend(c, b);
		}
	}

	public function new() {
		super();
	}

	// graphics paresseux : PIXI.Graphics enfant placé en dessous, hérite du blend.
	public var graphics(get, never):Graphics;
	function get_graphics():Graphics {
		if (_graphics == null) {
			_graphics = new Graphics();
			addChildAt(_graphics, 0);
			untyped _graphics.blendMode = _blendInt;
		}
		return _graphics;
	}

	// Non-inline : BSprite surcharge scaleX (retournement via bitmap, scale container positif).
	public var scaleX(get, set):Float;
	function get_scaleX():Float return scale.x;
	function set_scaleX(v:Float):Float { scale.x = v; return v; }

	public var scaleY(get, set):Float;
	inline function get_scaleY():Float return scale.y;
	inline function set_scaleY(v:Float):Float { scale.y = v; return v; }

	public var rotationDeg(get, set):Float; // pratique : rotation Flash = degrés
	inline function get_rotationDeg():Float return rotation * 180 / Math.PI;
	inline function set_rotationDeg(v:Float):Float { rotation = v * Math.PI / 180; return v; }

	public var mouseEnabled(get, set):Bool;
	inline function get_mouseEnabled():Bool return interactive;
	inline function set_mouseEnabled(v:Bool):Bool { interactive = v; return v; }

	public var mouseChildren(get, set):Bool;
	inline function get_mouseChildren():Bool return interactiveChildren;
	inline function set_mouseChildren(v:Bool):Bool { interactiveChildren = v; return v; }

	// buttonMode est déjà fourni par pixi.interaction.InteractiveTarget (hérité).
	public var useHandCursor:Bool = false;
	public var doubleClickEnabled:Bool = false;
	public var tabEnabled:Bool = false;
}
