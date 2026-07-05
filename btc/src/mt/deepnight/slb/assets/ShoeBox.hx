package mt.deepnight.slb.assets;

import mt.deepnight.slb.BLib;

// Version runtime de slb.assets.ShoeBox : l'original est une macro compile-time,
// inutilisable en JS. importXml(url) lit le registre BLib.REG (rempli par Boot avec
// XML + XML d'anims + atlas) et reconstruit un BLib.
class ShoeBox {
	public static function importXml(url:String):BLib {
		var e = BLib.REG.get(url);
		if (e == null) throw "ShoeBox.importXml: asset non enregistré: " + url;
		var lib = parseXml(e.xml, e.base, e.canvas);
		if (e.anims != null)
			applyAnims(lib, e.anims);
		return lib;
	}

	static function parseXml(xmlString:String, base:Dynamic, canvas:Dynamic):BLib {
		var lib = new BLib(base, canvas);
		var xml = new haxe.xml.Access(Xml.parse(xmlString));
		var removeExt = ~/\.(png|gif|jpeg|jpg)/gi;
		var leadNumber = ~/([0-9]*)$/;
		for (atlas in xml.nodes.TextureAtlas) {
			for (sub in atlas.nodes.SubTexture) {
				var id = sub.att.name;
				var x = Std.parseInt(sub.att.x);
				var y = Std.parseInt(sub.att.y);
				var wid = Std.parseInt(sub.att.width);
				var hei = Std.parseInt(sub.att.height);
				id = removeExt.replace(id, "");
				leadNumber.match(id);
				var frame = Std.parseInt(leadNumber.matched(1));
				if (frame != null) {
					var id2 = id.substr(0, leadNumber.matchedPos().pos);
					while (id2.length > 0 && id2.charAt(id2.length - 1) == "_")
						id2 = id2.substr(0, id2.length - 1);
					lib.sliceCustom(id2, frame, x, y, wid, hei);
				} else {
					lib.slice(id, x, y, wid, hei);
				}
			}
		}
		return lib;
	}

	static function applyAnims(lib:BLib, animsXml:String):Void {
		var xml = new haxe.xml.Access(Xml.parse(animsXml).firstElement());
		for (a in xml.nodes.a) {
			var group = a.att.group;
			var timing = a.has.timing ? Std.parseInt(a.att.timing) : null;
			var frames = BLib.parseAnimDefinition(a.innerHTML, timing);
			if (lib.exists(group))
				lib.__defineAnim(group, frames);
		}
	}
}
