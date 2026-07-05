import api.AKProtocol;

// Shadow de Game : ajoute le mode « Défi Coffres » (mode.Endless), choisi via le flag
// api.AKApi.defi. Endless hérite de League → getGameMode() renvoie GM_LEAGUE, donc on
// aiguille ici selon le flag (évite de toucher l'enum GameMode).
class Game extends flash.display.Sprite implements game.IGame {
	var mode				: Mode;
	var time				: Int;

	public function new() {
		super();
		time = 0;

		switch( api.AKApi.getGameMode() ) {
			case GameMode.GM_LEAGUE :
				if( api.AKApi.defi ) new mode.Endless(this);
				else new mode.League(this);
			case GameMode.GM_PROGRESSION : new mode.Progression(this);
		}
	}

	public function update(render:Bool) {
		mt.deepnight.Process.updateAll(render);
		mt.deepnight.mui.Component.updateAll();
		time++;
	}
}
