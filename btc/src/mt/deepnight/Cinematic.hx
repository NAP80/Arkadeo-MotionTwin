package mt.deepnight;

// Séquenceur de cinématique. Inerte : sert au tuto Progression, pas en League.
class Cinematic {
	public function new(?fps:Int = 30) {}

	public function signal(?id:String):Void {}

	public function update(?dt:Float = 1):Void {}
}
