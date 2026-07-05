// Serveur local Arkadeo : rend les pages (EJS), sert les assets statiques et
// enregistre les scores dans une base SQLite (fichier scores.db). Aucun service
// externe requis : `npm install && npm start`, puis http://localhost:3000.

const path = require("path");
const express = require("express");
const Database = require("better-sqlite3");
const { GROUPS } = require("./games.config");

const PORT = process.env.PORT || 3000;

// --- Base de données (SQLite) ---
const db = new Database(path.join(__dirname, "scores.db"));
db.pragma("journal_mode = WAL");
db.exec(`
  CREATE TABLE IF NOT EXISTS scores (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    game       TEXT NOT NULL,
    mode       TEXT NOT NULL,
    win        INTEGER,
    score      INTEGER DEFAULT 0,
    kados      INTEGER DEFAULT 0,
    durationMs INTEGER,
    lvupLevel  INTEGER,
    playedAt   TEXT NOT NULL,
    userAgent  TEXT,
    devUses    INTEGER DEFAULT 0
  );
`);

const insertResult = db.prepare(`
  INSERT INTO scores (game, mode, win, score, kados, durationMs, lvupLevel, playedAt, userAgent, devUses)
  VALUES (@game, @mode, @win, @score, @kados, @durationMs, @lvupLevel, @playedAt, @userAgent, @devUses)
`);

// --- App Express ---
const app = express();
app.set("view engine", "ejs");
app.set("views", path.join(__dirname, "views"));
app.use(express.json({ limit: "256kb" }));
app.use(express.urlencoded({ extended: true }));

// --- Assets statiques ---
// Jeux : no-store pour recharger le game.js recompilé sans cache navigateur.
const noStore = { setHeaders: (res) => res.setHeader("Cache-Control", "no-store") };
app.use("/new-capman/assets", express.static(path.join(__dirname, "capman", "web"), noStore));
app.use("/new-rock-faller/assets", express.static(path.join(__dirname, "rockfaller", "web"), noStore));
app.use("/assets", express.static(path.join(__dirname, "assets")));
app.use("/games", express.static(path.join(__dirname, "assets", "games")));
app.get("/favicon.ico", (req, res) => res.sendFile(path.join(__dirname, "assets", "favicon.ico")));

// --- API : enregistrer un résultat de partie ---
app.post("/api/results", (req, res) => {
  const { win, score, kados, durationMs, mode, lvupLevel, game, devUses } = req.body || {};
  const asInt = (v) => {
    const n = parseInt(v, 10);
    return Number.isFinite(n) ? n : 0;
  };
  const parseWin = (v) => v === true || v === "1" || v === "true" || v === 1;
  const row = {
    game: typeof game === "string" ? game : "unknown",
    mode: typeof mode === "string" ? mode : "league",
    // null = jeu sans condition de victoire (score pur) ; sinon 1 / 0.
    win: win == null ? null : parseWin(win) ? 1 : 0,
    score: asInt(score),
    kados: asInt(kados),
    durationMs: durationMs == null ? null : asInt(durationMs),
    lvupLevel: lvupLevel != null ? asInt(lvupLevel) || null : null,
    playedAt: new Date().toISOString(),
    userAgent: req.get("user-agent") || null,
    // Compteur interne d'usages Dev (jamais affiché au classement).
    devUses: asInt(devUses),
  };
  try {
    const info = insertResult.run(row);
    console.log(`[result] game=${row.game} mode=${row.mode} win=${row.win} score=${row.score} duree=${row.durationMs}ms -> id=${info.lastInsertRowid}`);
    res.json({ ok: true, id: info.lastInsertRowid });
  } catch (err) {
    console.error("[result] erreur insert:", err);
    res.status(500).json({ error: String(err) });
  }
});

// --- API : lister les dernières parties (classement) ---
app.get("/api/results", (req, res) => {
  const limit = Math.min(parseInt(req.query.limit, 10) || 50, 500);
  const conds = [];
  const params = { limit };
  if (req.query.mode) {
    conds.push("mode = @mode");
    params.mode = req.query.mode;
  }
  if (req.query.game) {
    conds.push("game = @game");
    params.game = req.query.game;
  }
  // noDev=1 : exclut les parties jouées avec un outil dev (devUses > 0).
  if (req.query.noDev) conds.push("(devUses IS NULL OR devUses <= 0)");
  const where = conds.length ? "WHERE " + conds.join(" AND ") : "";
  // Le userAgent enregistré en base n'est jamais renvoyé au client.
  const rows = db.prepare(`
    SELECT id, game, mode, win, score, kados, durationMs, lvupLevel, playedAt, devUses
    FROM scores ${where} ORDER BY playedAt DESC LIMIT @limit
  `).all(params);
  res.json(rows.map((r) => ({ ...r, win: r.win == null ? null : !!r.win })));
});

// --- API : statistiques agrégées ---
app.get("/api/stats", (req, res) => {
  const conds = [];
  const params = {};
  if (req.query.game) {
    conds.push("game = @game");
    params.game = req.query.game;
  }
  if (req.query.mode) {
    conds.push("mode = @mode");
    params.mode = req.query.mode;
  }
  if (req.query.noDev) conds.push("(devUses IS NULL OR devUses <= 0)");
  const where = conds.length ? "WHERE " + conds.join(" AND ") : "";
  const row = db.prepare(`
    SELECT COUNT(*) AS parties,
           SUM(CASE WHEN win = 1 THEN 1 ELSE 0 END) AS victoires,
           MAX(score) AS scoreMax,
           AVG(score) AS scoreMoyen,
           SUM(kados) AS kadosTotal
    FROM scores ${where}
  `).get(params);
  res.json(row || { parties: 0 });
});

// --- Pages ---
app.get("/", (req, res) => res.render("portal", { groups: GROUPS }));
app.get("/new-capman", (req, res) => res.render("new-capman-play"));
app.get("/new-capman/lvup", (req, res) => res.render("new-capman-lvup-play"));
app.get("/new-capman/speedrun", (req, res) => res.render("new-capman-speedrun-play"));
app.get("/new-capman/editor", (req, res) => res.render("new-capman-editor"));
app.get("/new-capman/classement", (req, res) => res.render("new-capman-classement"));

app.get("/new-rock-faller", (req, res) => res.render("new-rock-faller-play"));
app.get("/new-rock-faller/classement", (req, res) => res.render("new-rock-faller-classement"));

app.listen(PORT, () => {
  const base = `http://localhost:${PORT}`;
  console.log(`[http] Portail     : ${base}/`);
  console.log(`[http] CapMan      : ${base}/new-capman`);
  console.log(`[http] Rock Faller : ${base}/new-rock-faller`);
  console.log(`[sqlite] base      : ${path.join(__dirname, "scores.db")}`);
});
