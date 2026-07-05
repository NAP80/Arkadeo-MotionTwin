// Shadow de Lang : l'original utilise @:build(mt.data.Texts.build(...)), macro Haxe 2
// incompatible Haxe 4. On bake les quelques chaînes utiles en statiques.
class Lang {
	public static var CloseTutorial = "Espace pour continuer";
	public static var TutorialLocks = "Détruis toutes les serrures !";
	public static var TutorialMobs = "Élimine les monstres";
	public static var TutorialHero = "Fonce dans les ennemis";
	public static var LastLock = "Dernière serrure !";
	public static var ExitOpened = "Sortie ouverte !";

	public static function init(?raw:String):Void {
		// no-op : chaînes bakées ci-dessus.
	}
}
