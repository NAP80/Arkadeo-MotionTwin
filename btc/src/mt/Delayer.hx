package mt;

// Callbacks différés. add(fn, ms) est en millisecondes, mais update(dt) reçoit des
// FRAMES (1 par tick à 30 fps) : conversion via frameMs.
class Delayer {
	var frameMs:Float;
	var list:Array<{ms:Float, cb:Void->Void}>;

	public function new(?fps:Int = 30) {
		frameMs = 1000.0 / fps;
		list = [];
	}

	public function add(cb:Void->Void, ms:Float):Void {
		list.push({ms: ms, cb: cb});
	}

	public function addMs(cb:Void->Void, ms:Float):Void add(cb, ms);
	public function addS(cb:Void->Void, sec:Float):Void list.push({ms: sec * 1000, cb: cb});
	public function addF(cb:Void->Void, frames:Float):Void list.push({ms: frames * frameMs, cb: cb});

	public function update(?dt:Float = 1):Void {
		var step = dt * frameMs;
		for (e in list.copy()) {
			e.ms -= step;
			if (e.ms <= 0) {
				list.remove(e);
				e.cb();
			}
		}
	}

	public function destroy():Void {
		list = null;
	}
}
