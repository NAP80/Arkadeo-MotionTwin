package mt.flash;

import flash.display.DisplayObject;
import flash.display.DisplayObjectContainer;
import flash.display.Shape;
import flash.display.MovieClip;

// Gestion des plans de profondeur d'un Container. numChildren (Flash) est remplacé
// par children.length (PixiJS) ; le reste de l'API Container est identique.
class DepthManager {
	var root:DisplayObjectContainer;
	var plans:Array<DisplayObject>;
	var baseChildren:Int;

	public function new(r:DisplayObjectContainer) {
		root = r;
		baseChildren = root.children.length;
		plans = new Array();
	}

	public function getMC() return root;

	public function getPlan(n:Int):DisplayObject {
		var pmc = plans[n];
		if (pmc != null)
			return pmc;
		var sh = new Shape();
		sh.visible = false;
		sh.name = "Plan#" + n;
		root.addChildAt(sh, getBottom(n));
		plans[n] = sh;
		return sh;
	}

	function getBottom(plan:Int):Int {
		var n = plan;
		while (--n >= 0) {
			var mc = plans[n];
			if (mc != null)
				return root.getChildIndex(mc) + 1;
		}
		return baseChildren;
	}

	function getMCPlan(mc:DisplayObject):Int {
		var idx = root.getChildIndex(mc);
		for (p in 0...plans.length) {
			var pmc = plans[p];
			if (pmc != null && root.getChildIndex(pmc) > idx)
				return p;
		}
		return 0;
	}

	public function empty(plan:Int) {
		var mc = new MovieClip();
		root.addChildAt(mc, root.getChildIndex(getPlan(plan)));
		return mc;
	}

	public function add<T>(_mc:T, plan:Int):T {
		var mc:DisplayObject = cast _mc;
		if (mc.parent != null) mc.parent.removeChild(mc);
		root.addChildAt(mc, root.getChildIndex(getPlan(plan)));
		return _mc;
	}

	public function over(mc:DisplayObject) {
		var plan = getMCPlan(mc);
		root.addChildAt(mc, root.getChildIndex(getPlan(plan)) - 1);
	}

	public function under(mc:DisplayObject) {
		var plan = getMCPlan(mc);
		root.addChildAt(mc, getBottom(plan));
	}

	public function ysort(plan:Int) {
		var y:Float = -99999999;
		var start = getBottom(plan);
		var last = root.getChildIndex(getPlan(plan));
		for (i in start...last) {
			var mc = root.getChildAt(i);
			var mcy = mc.y;
			if (mcy >= y)
				y = mcy;
			else {
				var j = i - 1;
				while (j >= start) {
					var mc2 = root.getChildAt(j);
					if (mc2.y <= mcy)
						break;
					j--;
				}
				root.addChildAt(mc, j + 1);
			}
		}
	}

	public function clear(plan:Int) {
		var pmc = getPlan(plan);
		var pos = getBottom(plan);
		var count = root.getChildIndex(pmc) - pos;
		while (count > 0) {
			root.removeChildAt(pos);
			count--;
		}
	}

	public function destroy() {
		while (root.children.length > baseChildren) {
			var mc = root.getChildAt(baseChildren);
			mc.parent.removeChild(mc);
		}
		plans = [];
	}

	public function iterPlan(plan:Int, f:DisplayObject->Void) {
		var start = getBottom(plan);
		var last = root.getChildIndex(getPlan(plan));
		for (i in start...last)
			f(root.getChildAt(i));
	}
}
