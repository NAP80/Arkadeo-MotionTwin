package pixi.core;

import pixi.core.display.DisplayObject;

extern class TweenManager {
	public function new();

	public function update(?delta:Float):Void;
	public function getTweensForTarget(target:DisplayObject):Array<Tween>;
	public function createTween(target:DisplayObject):Tween;
	public function addTween(tween:Tween):Void;
	public function removeTween(tween:Tween):Void;
	public function _remove(tween:Tween):Void;
	public function _getDeltaMS():Int;
}
