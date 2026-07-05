package api;

// AKConst = type retourné par AKApi.const(n)/aconst([...]) : petit entier encapsulé.
// Contrat minimal : get() (lire) + add() (cumuler).
// BTC stocke ces objets (ex. Gold.VALUES = aconst([...])) et fait value.get() ; un Int
// brut crasherait la frame de ramassage.
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
