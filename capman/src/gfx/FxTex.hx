package gfx;

// Accès aux textures FX chargées par Boot (extraites du SWF, cf. extract_fx.ps1).
class FxTex {
	public static inline function tex(key:String):Dynamic {
		return untyped js.Syntax.code("PIXI.Loader.shared.resources[{0}].texture", key);
	}

	// AnimatedSprite des frames <prefix>0..count-1, ancrée au centre, lancée.
	public static function anim(prefix:String, count:Int, speed = 0.4):Dynamic {
		var texs:Array<Dynamic> = [];
		for (i in 0...count)
			texs.push(tex(prefix + i));
		var a:Dynamic = untyped js.Syntax.code("new PIXI.AnimatedSprite({0})", texs);
		a.anchor.set(0.5, 0.5);
		a.animationSpeed = speed;
		a.play();
		return a;
	}
}
