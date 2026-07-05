package api;

// Petite constante entière renvoyée par AKApi.const(n) : get() + add().
class AKConst {
	var v:Int;

	public function new(v:Int) {
		this.v = v;
	}

	public function get():Int {
		return v;
	}

	public function add(c:AKConst):Void {
		v += c.get();
	}
}
