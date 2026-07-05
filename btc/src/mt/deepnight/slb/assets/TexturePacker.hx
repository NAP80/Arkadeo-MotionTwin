package mt.deepnight.slb.assets;

import mt.deepnight.slb.BLib;

// Version runtime de slb.assets.TexturePacker : l'original est une macro
// compile-time. importXml(url) lit BLib.REG et reconstruit un BLib (le trim
// frameX/Y/frameWidth/frameHeight devient realFrame, anims regroupées par nom).
class TexturePacker {
	public static function importXml(url:String, ?treatFoldersAsPrefixes:Bool = false):BLib {
		var e = BLib.REG.get(url);
		if (e == null) throw "TexturePacker.importXml: asset non enregistré: " + url;
		return parseXml(e.xml, e.base, e.canvas, treatFoldersAsPrefixes);
	}

	static function makeChecksum(name:String, x:Int, y:Int, w:Int, h:Int, ox:Int, oy:Int, fw:Int, fh:Int):String {
		return name + "," + x + "," + y + "," + w + "," + h + "," + ox + "," + oy + "," + fw + "," + fh;
	}

	static function parseXml(xmlString:String, base:Dynamic, canvas:Dynamic, treatFoldersAsPrefixes:Bool):BLib {
		var lib = new BLib(base, canvas);
		var xml = new haxe.xml.Access(Xml.parse(xmlString));
		var removeExt = ~/\.(png|gif|jpeg|jpg)/gi;
		var leadNumber = ~/([0-9]*)$/;

		var slices:Map<String, Int> = new Map();
		var anims:Map<String, Array<Int>> = new Map();
		for (atlas in xml.nodes.TextureAtlas) {
			var lastName:String = null;
			var frame = 0;
			for (sub in atlas.nodes.SubTexture) {
				var rawName = sub.att.name;
				var x = Std.parseInt(sub.att.x);
				var y = Std.parseInt(sub.att.y);
				var wid = Std.parseInt(sub.att.width);
				var hei = Std.parseInt(sub.att.height);
				var offX = !sub.has.frameX ? 0 : Std.parseInt(sub.att.frameX);
				var offY = !sub.has.frameY ? 0 : Std.parseInt(sub.att.frameY);
				var fwid = !sub.has.frameWidth ? wid : Std.parseInt(sub.att.frameWidth);
				var fhei = !sub.has.frameHeight ? hei : Std.parseInt(sub.att.frameHeight);

				var name = removeExt.replace(rawName, "");
				if (name.indexOf("/") >= 0)
					name = treatFoldersAsPrefixes ? StringTools.replace(name, "/", "_") : name.substr(name.lastIndexOf("/") + 1);
				if (leadNumber.match(name)) {
					name = name.substr(0, leadNumber.matchedPos().pos);
					while (name.length > 0 && name.charAt(name.length - 1) == "_")
						name = name.substr(0, name.length - 1);
				}

				if (lastName == null || lastName != name)
					frame = 0;

				var csum = makeChecksum(name, x, y, wid, hei, offX, offY, fwid, fhei);
				if (!slices.exists(csum)) {
					slices.set(csum, frame);
					lib.sliceCustom(name, frame, x, y, wid, hei, {x: offX, y: offY, realWid: fwid, realHei: fhei});
					frame++;
				}

				var realFrame = slices.get(csum);
				if (!anims.exists(name))
					anims.set(name, [realFrame]);
				else
					anims.get(name).push(realFrame);

				lastName = name;
			}
		}

		for (k in anims.keys())
			lib.__defineAnim(k, anims.get(k));

		return lib;
	}
}
