package funkin.gameplay.song;

@:structInit
class SongTrackData {
	public var spectator:Array<String>;
	public var opponent:Array<String>;
	public var player:Array<String>;
}

@:structInit
class SongData {
	public var title:String;

	public var mixes:Array<String>;
	public var difficulties:Array<String>;
	
	public var timingPoints:Array<TimingPoint>;

	public var artist:String;
	public var charter:String;

	@:optional
	public var tracks:SongTrackData;
}

@:structInit
class FreeplayData {
	public var ratings:Map<String, Int>;//DynamicAccess<Int>;

	public var icon:String;
	public var album:String;

    public function getRating(difficulty:String):Int {
        return ratings.get(difficulty);
    }
}

@:structInit
class GameplayData {
	public var characters:Map<String, String>;//DynamicAccess<String>;
	public var scrollSpeed:Map<String, Float>;//DynamicAccess<Float>;

	@:optional
	@:default(true)
	public var allowOpponentMode:Bool;

	@:optional
	@:default("stage")
	public var stage:String;

	@:optional
	@:default("default")
	public var noteSkin:String;

	@:optional
	@:default("default")
	public var uiSkin:String;

	@:optional
	@:default("default")
	public var hudSkin:String;

    public function getCharacter(type:String):String {
        return characters.get(type);
    }

    public function getScrollSpeed(difficulty:String):Float {
        return scrollSpeed.get(difficulty);
    }
}

@:structInit
class SongMetadata {
	public var song:SongData;
	public var freeplay:FreeplayData;
	public var game:GameplayData;

	public static function load(song:String, ?mix:String, ?loaderID:String):SongMetadata {
        if(mix == null || mix.length == 0)
            mix = "default";

		final parser:JsonParser<SongMetadata> = new JsonParser<SongMetadata>();
		parser.ignoreUnknownVariables = true;

		final meta:SongMetadata = parser.fromJson(FlxG.assets.getText(Paths.json('gameplay/songs/${song}/${mix}/metadata', loaderID)));
		if(mix == "default")
			meta.song.mixes.insert(0, "default");

		return meta;
    }

	public static function stringify(chart:SongMetadata):String {
		final writer:JsonWriter<SongMetadata> = new JsonWriter<SongMetadata>();
		return writer.write(chart, "\t");
	}
}