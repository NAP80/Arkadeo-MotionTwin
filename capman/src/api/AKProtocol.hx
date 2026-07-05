package api;

// Ordre des constructeurs : 0 = PROGRESSION, 1 = LEAGUE - l'ordre compte (Type.createEnumIndex / désérialisation).
enum GameMode {
	GM_PROGRESSION;
	GM_LEAGUE;
}

typedef SecureInGamePrizeTokens = {
	var amount:AKConst;
	var score:AKConst;
	var frame:Int;
}
