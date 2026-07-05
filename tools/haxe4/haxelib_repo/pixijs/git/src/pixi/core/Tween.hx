package pixi.core;

import pixi.core.display.DisplayObject;

extern class Tween {
	public var time:Int;
	public var active:Bool;
	public var easing:Easing;
	public var expire:Bool;
	public var repeat:Int;
	public var loop:Bool;
	public var delay:Int;
	public var pingPong:Bool;
	public var isStarted:Bool;
	public var isEnded:Bool;
	public var _to:Dynamic;
	public var _from:Dynamic;
	public var _delayTime:Int;
	public var _elapsedTime:Int;
	public var _repeat:Int;
	public var _pingPong:Bool;
	public var _chainTween:Tween;
	// public var path:TweenPath;
	public var pathReverse:Bool;
	public var pathFrom:Int;
	public var pathTo:Int;

	public function new(target:DisplayObject, manager:TweenManager);
	public function addTo(manager:TweenManager):Tween;
	public function chain(tween:Tween):Tween;
	public function start():Tween;
	public function stop():Tween;
	public function to(data:Dynamic):Tween;
	public function from(data:Dynamic):Tween;
	public function remove():Tween;
	public function clear():Void;
	public function reset():Tween;
	public function update(delta:Float, deltaMS:Int):Void;
	public function _parseData():Void;
	public function _apply(time:Float):Void;
	public function _canUpdate():Bool;
}
