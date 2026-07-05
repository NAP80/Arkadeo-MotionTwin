package mt.deepnight;

// Process de base (Mode en dérive) : root + timers cd/delayer/tw, pause, update
// overridable, updateAll global. Cadence fixe 30 fps -> dt=1 par tick.
class Process {
	public static var ALL:Array<Process> = [];

	public var root:flash.display.Sprite;
	public var cd:mt.Cooldown;
	public var delayer:mt.Delayer;
	public var tw:mt.deepnight.Tweenie;
	public var paused:Bool;
	public var destroyed:Bool;
	public var rendering:Bool;
	public var time:Int; // frames écoulées

	public function new(?fps:Float = 30) {
		root = new flash.display.Sprite();
		cd = new mt.Cooldown(fps);
		delayer = new mt.Delayer(Std.int(fps));
		tw = new mt.deepnight.Tweenie(Std.int(fps));
		paused = false;
		destroyed = false;
		rendering = true;
		time = 0;
		ALL.push(this);
	}

	// Overridables
	public function update():Void {}
	public function postUpdate():Void {}

	public function unregister():Void {
		if (destroyed) return;
		destroyed = true;
		ALL.remove(this);
		if (cd != null) cd.destroy();
		if (delayer != null) delayer.destroy();
		if (tw != null) tw.destroy();
		if (root != null && root.parent != null) root.parent.removeChild(root);
	}

	public function pause():Void paused = true;
	public function resume():Void paused = false;
	public inline function togglePause():Void if (paused) resume() else pause();

	public static function updateAll(rendering:Bool):Void {
		for (p in ALL.copy()) {
			if (p.paused || p.destroyed) continue;
			p.rendering = rendering;
			if (p.delayer != null) p.delayer.update(1);
			if (p.cd != null) p.cd.update(1);
			if (p.tw != null) p.tw.update(1);
			p.time++;
			if (!p.paused && !p.destroyed) p.update();
		}
	}
}
