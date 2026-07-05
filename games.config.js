// Registre du portail (page d'accueil). Pour ajouter un jeu, ajoutez une tuile
// dans GROUPS (ou un nouveau groupe). Chaque tuile : { name, icon|emoji, btns:[
// { href, btn, btnClass } ] }, où btnClass pilote la couleur du bouton.
const GROUPS = [
  {
    label: "Arkadeo HTML5",
    tiles: [
      {
        name: "CapMan",
        icon: "/games/capman/icons/r_capman_a.png",
        btns: [
          { href: "/new-capman", btn: "League", btnClass: "league" },
          { href: "/new-capman/lvup", btn: "LvUP", btnClass: "lvup" },
          { href: "/new-capman/speedrun", btn: "SpeedRun", btnClass: "speedrun" },
          { href: "/new-capman/editor", btn: "Éditeur", btnClass: "editor" },
          { href: "/new-capman/classement", btn: "Classement", btnClass: "classement" },
        ],
      },
      {
        name: "Rock Faller",
        icon: "/games/rockFaller/icons/r_rock_a.png",
        btns: [
          { href: "/new-rock-faller", btn: "League", btnClass: "league" },
          { href: "/new-rock-faller?mode=lvup", btn: "LvUP", btnClass: "lvup" },
          { href: "/new-rock-faller/classement", btn: "Classement", btnClass: "classement" },
        ],
      },
    ],
  },
];

module.exports = { GROUPS };
