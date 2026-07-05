package pixi.core;

import pixi.core.math.Point;

extern class TweenPath {
	public function new();
	public function moveTo(x:Int, y:Int):TweenPath;
	public function lineTo(x:Int, y:Int):TweenPath;
	public function bezierCurveTo(cpX:Int, cpY:Int, cpX2:Int, cpY2:Int, toX:Int, toY:Int):TweenPath;
	public function quadraticCurveTo(cpX:Int, cpY:Int, toX:Int, toY:Int):TweenPath;
	public function arcTo(x1:Int, y1:Int, x2:Int, y2:Int, radius:Int):TweenPath;
	public function arc(cx:Int, cy:Int, radius:Int, startAngle:Int, endAngle:Int, anticlockwise:Bool):TweenPath;
	public function drawShape(shape:Dynamic):TweenPath;
	public function getPoint(num:Int):Point;
	public function distanceBetween(num1:Int, num2:Int):Float;
	public function totalDistance():Float;
	public function getPointAt(num:Int):Point;
	public function getPointAtDistance(distance:Float):Point;
	public function parsePoints():TweenPath;
	public function clear():TweenPath;
	public function length():Int;
}
