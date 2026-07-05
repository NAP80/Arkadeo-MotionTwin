// New Rock Faller - backend audio (HTML5 Audio).
// Musique en boucle + 29 SFX du jeu d'origine. Actif par défaut ; démarrage au
// 1er geste utilisateur (clic « Jouer ») pour respecter la politique d'autoplay.
package snd;

import js.html.Audio;

class Sfx {
	static inline var BASE = "/new-rock-faller/assets/sounds/";
	static inline var POOL_PER_NAME = 4;

	static var muted:Bool = false;
	static var music:Audio;
	static var musicName:String;
	// Pool d'éléments Audio réutilisés par son : sans ça, chaque SFX faisait `new Audio()` (un
	// élément média + décodage par LECTURE) → churn décodeur/mémoire en cas de sons rapprochés.
	// On réutilise un petit anneau par son → overlap limité conservé, total borné (~sons × 4).
	static var pool:Map<String, Array<Audio>> = new Map();
	static var poolIdx:Map<String, Int> = new Map();

	// Joue un SFX (élément mutualisé via un anneau → chevauchement limité, pas de churn).
	public static function play(name:String, ?volume:Float = 1.0):Void {
		if (muted)
			return;
		var a = acquire(name);
		a.volume = volume;
		try a.currentTime = 0 catch (e:Dynamic) {}
		try
			a.play()
		catch (e:Dynamic) {}
	}

	static function acquire(name:String):Audio {
		var ring = pool.get(name);
		if (ring == null) {
			ring = [];
			pool.set(name, ring);
			poolIdx.set(name, 0);
		}
		if (ring.length < POOL_PER_NAME) {
			var a = new Audio(BASE + name + ".mp3");
			ring.push(a);
			return a;
		}
		var i = poolIdx.get(name);
		var a = ring[i];
		poolIdx.set(name, (i + 1) % POOL_PER_NAME);
		return a;
	}

	// Démarre (ou redémarre) la musique en boucle. À appeler depuis un geste
	// utilisateur (sinon le navigateur bloque l'autoplay).
	public static function startMusic(name:String, ?volume:Float = 0.6):Void {
		musicName = name;
		if (music == null) {
			music = new Audio(BASE + name + ".mp3");
			music.loop = true;
		}
		music.volume = volume;
		if (!muted) {
			try
				music.play()
			catch (e:Dynamic) {}
		}
	}

	public static function setMuted(m:Bool):Void {
		muted = m;
		if (music != null) {
			if (m)
				music.pause();
			else {
				try
					music.play()
				catch (e:Dynamic) {}
			}
		}
	}

	public static function toggleMuted():Bool {
		setMuted(!muted);
		return muted;
	}

	public static function isMuted():Bool {
		return muted;
	}
}
