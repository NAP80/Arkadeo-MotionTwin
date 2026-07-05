// Curseur de lecture sur une timeline d'indices (avec ou sans boucle).
package mt.pix;

class Anim {
	public var loop:Bool;
	public var timeline:Array<Int>;

	public var cursor:Float;
	public var playSpeed:Float;
	public var el:Element;

	public function new(el:Element) {
		this.el = el;
		timeline = [0];
		cursor = 0;
		playSpeed = 1;
		loop = true;
	}

	public inline function isFinished() {
		return cursor == timeline.length - 1;
	}

	public function update() {
		cursor += playSpeed;
		if (cursor >= timeline.length) {
			if (loop) {
				cursor -= timeline.length;
			} else {
				cursor = timeline.length - 1;
				playSpeed = 0;
			}
			onFinish();
		}
		if (cursor < 0) {
			if (loop) {
				cursor += timeline.length;
			} else {
				cursor = 0;
				playSpeed = 0;
			}
			onFinish();
		}
	}

	dynamic public function onFinish() {}

	public function play(speed = 1.0) {
		playSpeed = speed;
	}

	public function stop() {
		play(0);
	}

	public function goto(n) {
		cursor = n;
	}

	public function gotoRandom() {
		cursor = Std.random(timeline.length);
	}

	public function getRandomFrame() {
		var id = timeline[Std.random(timeline.length)];
		return el.store.get(id);
	}

	public function getCurrentFrame() {
		var id = timeline[Std.int(cursor)];
		return el.store.get(id);
	}

	public function reverse() {
		playSpeed = -playSpeed;
		cursor = timeline.length - (1 + cursor);
	}
}
