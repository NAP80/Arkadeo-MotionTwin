package mt;

// Cooldowns clavés (frame-based). BTC passe des FRAMES via Const.seconds() ; à 30 fps
// fixe, update(1) par frame. new() sans arg (la lib d'origine exigeait new(fps:Float)).
class Cooldown {
	var cds:Map<String, Float>;
	var cbs:Map<String, Void->Void>;

	public function new(?fps:Float = 30) {
		cds = new Map();
		cbs = new Map();
	}

	public function set(k:String, frames:Float):Void {
		cds.set(k, frames);
	}

	public function has(k:String):Bool {
		return cds.exists(k) && cds.get(k) > 0;
	}

	public function get(k:String):Float {
		return cds.exists(k) ? cds.get(k) : 0;
	}

	public function unset(k:String):Void {
		cds.remove(k);
		cbs.remove(k);
	}

	// "has? sinon set et renvoie false".
	public function hasSet(k:String, frames:Float):Bool {
		if (has(k)) return true;
		set(k, frames);
		return false;
	}

	public function onComplete(k:String, cb:Void->Void):Void {
		cbs.set(k, cb);
	}

	public function update(?dt:Float = 1):Void {
		for (k in [for (kk in cds.keys()) kk]) {
			var v = cds.get(k) - dt;
			if (v <= 0) {
				cds.remove(k);
				if (cbs.exists(k)) {
					var cb = cbs.get(k);
					cbs.remove(k);
					cb();
				}
			} else {
				cds.set(k, v);
			}
		}
	}

	public function destroy():Void {
		cds = null;
		cbs = null;
	}
}
