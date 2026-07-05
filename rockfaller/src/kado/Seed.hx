package kado;

class Seed {
	static var gameplayRng:mt.Rand;
	static var vfxRng:mt.Rand;

	public static function init(seedHash:Int):Void {
		gameplayRng = new mt.Rand(seedHash);
		vfxRng = new mt.Rand(seedHash);
	}

	static inline function ensureInit():Void {
		if (gameplayRng == null || vfxRng == null) {
			init(0);
		}
	}

	public static inline function rand():Float {
		return randGameplay();
	}

	public static inline function random(max:Int):Int {
		return randomGameplay(max);
	}

	public static inline function randGameplay():Float {
		ensureInit();
		return gameplayRng.rand();
	}

	public static inline function randomGameplay(max:Int):Int {
		if (max <= 0)
			return 0;
		ensureInit();
		return gameplayRng.random(max);
	}

	public static inline function randVfx():Float {
		ensureInit();
		return vfxRng.rand();
	}

	public static inline function randomVfx(max:Int):Int {
		if (max <= 0)
			return 0;
		ensureInit();
		return vfxRng.random(max);
	}
}
