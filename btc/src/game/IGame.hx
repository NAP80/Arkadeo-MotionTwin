package game;

// Interface game.IGame : le loader d'origine appelait update(render) chaque frame ;
// ici c'est Boot qui pilote la boucle.
interface IGame {
	function update(render:Bool):Void;
}
