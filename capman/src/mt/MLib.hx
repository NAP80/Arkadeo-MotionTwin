package mt;

class MLib {
	public static function max(a, b) {
		return a > b ? a : b;
	}

	public static function min(a, b) {
		return a < b ? a : b;
	}

	public static function abs(v) {
		return v < 0 ? -v : v;
	}

	public static function isEven(n:Int):Bool {
		return n % 2 == 0;
	}
}
