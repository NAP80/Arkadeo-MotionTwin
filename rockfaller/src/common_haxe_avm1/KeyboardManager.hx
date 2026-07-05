package common_haxe_avm1;

import haxe.ds.IntMap;
import js.html.KeyboardEvent;

class KeyboardManager {
	static public inline var ENTER = 13;
	static public inline var SHIFT = 16;
	static public inline var CONTROL = 17;
	static public inline var ESCAPE = 27;
	static public inline var SPACE = 32;
	static public inline var DOWN = 40;
	static public inline var UP = 38;
	static public inline var LEFT = 37;
	static public inline var RIGHT = 39;
	static public inline var ARROW_DOWN = 40;
	static public inline var ARROW_UP = 38;
	static public inline var ARROW_LEFT = 37;
	static public inline var ARROW_RIGHT = 39;
	static public inline var A = 65;
	static public inline var B = 66;
	static public inline var D = 68;
	static public inline var G = 71;
	static public inline var Q = 81;
	static public inline var S = 83;
	static public inline var V = 86;
	static public inline var W = 87;
	static public inline var Z = 90;
	static public inline var F1 = 112;
	static public inline var F2 = 113;
	static public inline var F3 = 114;
	static public inline var F4 = 115;
	static public inline var F5 = 116;
	static public inline var F6 = 117;
	static public inline var F7 = 118;
	static public inline var F8 = 119;

	static private var keyState:IntMap<Bool>;
	static private var justPressed:IntMap<Bool>;
	static private var frameKeyChanges:Array<{keyCode:Int, isDown:Bool}> = [];
	static private var isInitialized:Bool = false;
	static private var inputLocked:Bool = false;
	static private var pendingOps:Array<{keyCode:Int, isDown:Bool}> = [];

	static public var lastDown:Int;

	static public function init() {
		if (isInitialized) {
			return;
		}

		keyState = new IntMap();
		justPressed = new IntMap();
		frameKeyChanges = [];
		isInitialized = true;

		js.Browser.window.addEventListener("keydown", onKeyDown);
		js.Browser.window.addEventListener("keyup", onKeyUp);

		/*window.js.Browser.dEventListener("keydown", function(e) {
			if (["Space", "ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"].indexOf(e.code) > -1) {
				e.preventDefault();
			}
		}, false);*/
	}

	static private function onKeyUp(e:KeyboardEvent):Void {
		if ([SPACE, ARROW_UP, ARROW_DOWN, ARROW_LEFT, ARROW_RIGHT].contains(e.keyCode)) {
			e.preventDefault();
		}
		if (inputLocked) {
			return;
		}
		queueKeyOp(e.keyCode, false);
	}

	static private function onKeyDown(e:KeyboardEvent) {
		if ([SPACE, ARROW_UP, ARROW_DOWN, ARROW_LEFT, ARROW_RIGHT].contains(e.keyCode)) {
			e.preventDefault();
		}
		if (inputLocked) {
			return;
		}
		queueKeyOp(e.keyCode, true);
	}

	static public function setInputLocked(value:Bool):Void {
		inputLocked = value;
		if (value) {
			pendingOps = [];
		}
	}

	static public function queueVirtualKeyDown(keyCode:Int):Void {
		queueKeyOp(keyCode, true);
	}

	static public function queueVirtualKeyUp(keyCode:Int):Void {
		queueKeyOp(keyCode, false);
	}

	static public function queueReplayKeyDown(keyCode:Int):Void {
		queueKeyOp(keyCode, true, true);
	}

	static public function queueReplayKeyUp(keyCode:Int):Void {
		queueKeyOp(keyCode, false, true);
	}

	static public function beginFrame():Int {
		ensureInitialized();
		justPressed = new IntMap();
		frameKeyChanges = [];
		if (pendingOps.length == 0) {
			return 0;
		}

		var ops = pendingOps;
		pendingOps = [];
		var applied = 0;
		for (op in ops) {
			if (op.isDown) {
				var wasDown = keyState.exists(op.keyCode);
				setKeyDown(op.keyCode);
				if (!wasDown) {
					justPressed.set(op.keyCode, true);
					frameKeyChanges.push({keyCode: op.keyCode, isDown: true});
				}
			} else {
				var wasDown = keyState.exists(op.keyCode);
				setKeyUp(op.keyCode);
				if (wasDown) {
					frameKeyChanges.push({keyCode: op.keyCode, isDown: false});
				}
			}
			applied++;
		}
		return applied;
	}

	static public function getFrameKeyChanges():Array<{keyCode:Int, isDown:Bool}> {
		ensureInitialized();
		return frameKeyChanges.copy();
	}

	static public function setKeyDown(keyCode:Int):Void {
		ensureInitialized();
		keyState.set(keyCode, true);
		lastDown = keyCode;
	}

	static public function setKeyUp(keyCode:Int):Void {
		ensureInitialized();
		keyState.remove(keyCode);
	}

	static public function clearState():Void {
		ensureInitialized();
		keyState = new IntMap();
		justPressed = new IntMap();
		frameKeyChanges = [];
		pendingOps = [];
		lastDown = 0;
	}

	static public function isDown(keyCode:Int):Bool {
		ensureInitialized();
		return keyState.exists(keyCode);
	}

	static public function isJustDown(keyCode:Int):Bool {
		ensureInitialized();
		return justPressed.exists(keyCode);
	}

	static public function isArrowDown():Bool {
		return isDown(ARROW_RIGHT) || isDown(ARROW_UP) || isDown(ARROW_LEFT) || isDown(ARROW_DOWN);
	}

	static private inline function ensureInitialized():Void {
		if (!isInitialized) {
			init();
		}
	}

	static private inline function queueKeyOp(keyCode:Int, isDown:Bool, bypassLock:Bool = false):Void {
		ensureInitialized();
		if (inputLocked && !bypassLock) {
			return;
		}
		pendingOps.push({keyCode: keyCode, isDown: isDown});
	}
}
