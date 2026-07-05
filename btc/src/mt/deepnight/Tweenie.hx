package mt.deepnight;

// Tweens de propriétés par réflexion. create(obj, prop, target, [ease], [durationMs]),
// terminate, update(dt). L'ease passé est ignoré (courbe fixe, cf. update).
typedef Tween = {
	obj:Dynamic,
	prop:String,
	from:Float,
	to:Float,
	ms:Float,
	t:Float,
	?onEnd:Void->Void,
};

class Tweenie {
	var frameMs:Float;
	var all:Array<Tween>;

	public function new(?fps:Int = 30) {
		frameMs = 1000.0 / fps;
		all = [];
	}

	// Signature tolérante : 4e/5e arg = durée (ms) et/ou ease (ignoré).
	public function create(obj:Dynamic, prop:String, to:Float, ?a:Dynamic, ?b:Dynamic):Tween {
		var ms:Float = 300;
		if (b != null && Std.isOfType(b, Float)) ms = b;
		else if (a != null && Std.isOfType(a, Float)) ms = a;
		terminate(obj, prop);
		var f:Float = 0;
		var cur = Reflect.field(obj, prop);
		if (cur != null && Std.isOfType(cur, Float)) f = cur;
		var tw:Tween = {obj: obj, prop: prop, from: f, to: to, ms: ms, t: 0, onEnd: null};
		all.push(tw);
		return tw;
	}

	public function terminate(obj:Dynamic, ?prop:String):Void {
		all = all.filter(function(tw) return !(tw.obj == obj && (prop == null || tw.prop == prop)));
	}

	static inline function bezier(t:Float, p0:Float, p1:Float, p2:Float, p3:Float):Float {
		return (1 - t) * (1 - t) * (1 - t) * p0 + 3 * t * (1 - t) * (1 - t) * p1 + 3 * t * t * (1 - t) * p2 + t * t * t * p3;
	}

	public function update(?dt:Float = 1):Void {
		for (tw in all.copy()) {
			tw.t += dt * frameMs;
			var r = tw.ms <= 0 ? 1.0 : tw.t / tw.ms;
			if (r > 1) r = 1;
			var er = bezier(r, 0, 0, 1, 1); // courbe ease-in-out fixe
			Reflect.setField(tw.obj, tw.prop, tw.from + (tw.to - tw.from) * er);
			if (r >= 1) {
				all.remove(tw);
				if (tw.onEnd != null) tw.onEnd();
			}
		}
	}

	public function destroy():Void {
		all = null;
	}
}
