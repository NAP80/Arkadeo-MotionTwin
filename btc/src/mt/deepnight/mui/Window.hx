package mt.deepnight.mui;

import flash.display.Sprite;

// Stub mui.Window (ne dérive pas de la hiérarchie Flash). Couvre l'API du tuto
// Progression.
class Window {
	public var wrapper:Sprite;
	public var padding:Int = 0;
	public var color:Int = 0;
	public var x:Float = 0;
	public var y:Float = 0;

	public function new(parent:Sprite, ?modal:Bool = false) {
		wrapper = new Sprite();
		if (parent != null)
			parent.addChild(wrapper);
	}

	public function setWidth(w:Float):Void {}
	public function label(str:String):Label return new Label();
	public function separator():Void {}
	public function getWidth():Float return 0;
	public function getHeight():Float return 0;
	public function destroy():Void {}
}
