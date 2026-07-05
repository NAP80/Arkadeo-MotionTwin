package kado;

class FixedFramerate {
	public static inline var STEP = 1 / 32 * 1000;

	public var alpha(default, null):Float = 0;

	var accumulator:Float = 0;
	var update:Float->Void;

	public function new(update:Float->Void) {
		this.update = update;
	}

	public function onTick(elapsedMS:Float):Void {
		accumulator += elapsedMS;

		if (accumulator > 250) {
			#if DEBUG
			trace("WARN: FixedFramerate: large frame time " + accumulator + "ms");
			#end
			accumulator = 250;
		}

		while (accumulator >= STEP) {
			update(STEP);
			accumulator -= STEP;
		}

		alpha = accumulator / STEP;
	}
}
