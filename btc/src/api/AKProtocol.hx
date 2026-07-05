package api;

// Types « protocole » partagés jeu↔loader d'origine utilisés par BTC.
// Ordre des constructeurs à préserver (index 0 = PROGRESSION, 1 = LEAGUE).
enum GameMode {
	GM_PROGRESSION;
	GM_LEAGUE;
}

// Cadeau in-game (PK). Vide en standalone (getInGamePrizeTokens() = []).
typedef SecureInGamePrizeTokens = {
	var amount:AKConst;
	var score:AKConst;
	var frame:Int;
}
