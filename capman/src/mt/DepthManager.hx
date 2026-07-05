package mt;

import pixi.core.display.Container;
import pixi.core.display.DisplayObject;

// Gère la profondeur via le tri natif PixiJS v5 : sortableChildren + un zIndex par enfant = plan*PLAN_STRIDE + rang d'insertion.
// over() repousse au sommet du plan, empty() crée un sous-conteneur trié.
class DepthManager {
	static inline var PLAN_STRIDE = 100000;

	public var root_mc:Container;

	var counter:Int = 0;

	public function new(mc:Container) {
		root_mc = mc;
		untyped root_mc.sortableChildren = true;
	}

	public function getMC():Container {
		return root_mc;
	}

	public function add(mc:DisplayObject, plan:Int):DisplayObject {
		untyped mc.zIndex = plan * PLAN_STRIDE + (counter++);
		root_mc.addChild(mc);
		return mc;
	}

	public function empty(plan:Int):Container {
		var c = new Container();
		untyped c.sortableChildren = true;
		untyped c.zIndex = plan * PLAN_STRIDE + (counter++);
		root_mc.addChild(c);
		return c;
	}

	// Repousse mc au sommet de SON plan (sans changer de plan).
	public function over(mc:DisplayObject):Void {
		var z:Int = untyped mc.zIndex;
		var plan = Std.int(z / PLAN_STRIDE);
		untyped mc.zIndex = plan * PLAN_STRIDE + (counter++);
	}

	public function destroy():Void {
		while (root_mc.children.length > 0)
			root_mc.removeChildAt(0);
	}
}
