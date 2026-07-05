package mt.deepnight.mui;

import flash.display.Sprite;

enum LabelAlign {
	Left;
	Center;
	Right;
}

// Stub mui.Label (ne dérive pas de la hiérarchie Flash).
class Label {
	public var wrapper:Sprite;
	public var multiline:Bool = false;

	public function new() {
		wrapper = new Sprite();
	}

	public function setFont(embedId:String, size:Int, ?color:Int = -1):Void {}
	public function setHAlign(a:LabelAlign):Void {}
}
