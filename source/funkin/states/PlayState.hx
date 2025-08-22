package funkin.states;

import haxe.io.Path;
import lime.system.System;

import openfl.utils.AssetCache as OpenFLAssetCache;

import flixel.text.FlxText;
import flixel.math.FlxPoint;

import flixel.util.FlxTimer;
import flixel.util.FlxSignal;

import funkin.backend.ContentMetadata;
import funkin.backend.assets.loaders.AssetLoader;

import funkin.gameplay.Countdown;
import funkin.gameplay.FunkinCamera;
import funkin.gameplay.PlayField;
import funkin.gameplay.character.Character;

import funkin.backend.events.Events;
import funkin.backend.events.ActionEvent;

import funkin.backend.events.CountdownEvents;
import funkin.backend.events.GameplayEvents;
import funkin.backend.events.NoteEvents;

import funkin.gameplay.UISkin;
import funkin.gameplay.notes.NoteSkin;
import funkin.gameplay.notes.StrumLine;

import funkin.gameplay.PlayerStats;
import funkin.gameplay.character.CharacterData;

import funkin.gameplay.events.*;
import funkin.gameplay.events.EventRunner;

import funkin.gameplay.hud.*;
import funkin.gameplay.hud.BaseHUD;

import funkin.gameplay.scoring.Scoring;
import funkin.gameplay.scoring.system.*;

import funkin.gameplay.song.NoteData;
import funkin.gameplay.song.EventData;
import funkin.gameplay.song.ChartData;
import funkin.gameplay.song.Highscore;

import funkin.gameplay.song.VocalGroup;

import funkin.gameplay.stage.Stage;
import funkin.gameplay.stage.StageData;
import funkin.gameplay.stage.props.ComboProp;

import funkin.gameplay.cutscenes.*;
import funkin.gameplay.cutscenes.Cutscene;

import funkin.states.menus.StoryMenuState;
import funkin.states.menus.FreeplayState;
import funkin.states.editors.ChartEditor;

import funkin.substates.PauseSubState;
import funkin.substates.GameOverSubState;
import funkin.substates.transition.TransitionSubState;

// import scripting events anyways because i'm too lazy
// to make it work on no scripting mode lol!!
#if SCRIPTING_ALLOWED
import funkin.scripting.FunkinScript;
import funkin.scripting.FunkinScriptGroup;
#end

enum abstract CameraTarget(Int) from Int to Int {
	final OPPONENT = 0;
	final PLAYER = 1;
	final SPECTATOR = 2;
}

class PlayState extends FunkinState {
	public static var lastParams:PlayStateParams = {
		song: "bopeebo",
		difficulty: "hard"
	};
	public static var instance:PlayState;
	public static var deathCounter:Int = 0;
	
	public static var storyLevel:String;
	public static var storyStats:PlayerStats;
	public static var storyPlaylist:Array<String> = [];
	
	public static var seenCutscene:Bool = false;

	public var isStoryMode(default, null):Bool = false;
	
	public var currentSong:String;
	public var currentDifficulty:String;
	public var currentMix:String;

	public var spectator:Character;
	public var opponent:Character;
	public var player:Character;

	public var stage:Stage;
	public var camFollow:FlxObject;
	public var isCameraOnForcedPos:Bool = false;

	public var paused:Bool = false;
	public var exitingState:Bool = false;

	public var inCutscene:Bool = false;
	public var minimalMode:Bool = false;

	public var startCutscenes:Array<Cutscene> = [];
	public var endCutscenes:Array<Cutscene> = [];

	public var cutscene:Cutscene;

	#if SCRIPTING_ALLOWED
	public var scriptsAllowed:Bool = true;
	#end

	/**
	 * The current character that is being followed by the camera.
	 * 
	 * - `0` - Opponent
	 * - `1` - Player
	 * - `2` - Spectator
	 */
	public var curCameraTarget:CameraTarget = OPPONENT;

	public var camGame:FunkinCamera;
	public var camHUD:FunkinCamera;
	public var camOther:FunkinCamera;
	
	public var inst:FlxSound;
	public var vocals:VocalGroup;

	public var currentChart:ChartData;
	public var playField:PlayField;

	public var opponentStrumLine(get, never):StrumLine;
	public var opponentStrums(get, never):StrumLine;
	
	public var playerStrumLine(get, never):StrumLine;
	public var playerStrums(get, never):StrumLine;

	public var opponentMode(get, set):Bool;

	public var countdown:Countdown;
	public var eventRunner:EventRunner;

	public var songLength:Float = 0;
	public var songPercent(get, never):Float;
	
	public var startedCountdown:Bool = false;
	public var startingSong:Bool = true;
	public var endingSong:Bool = false;

	/**
	 * How many beats it will take before the camera bumps.
	 * 
	 * If this value is exactly `0`, the camera won't bump.
	 * If this value is below `0`, the camera will bump every measure.
	 */
	public var camZoomingInterval:Int = -1;

	/**
	 * The intensity of the camera bumping.
	 */
	public var camZoomingIntensity:Float = 1;

	public var camGameZoomLerp:Float = 0.05;
	public var camHUDZoomLerp:Float = 0.05;

	public var canPause:Bool = true;
	public var chartingMode:Bool = false;

	public var practiceMode(default, set):Bool = false;
	public var playbackRate(default, set):Float = 1;

	public var canDie:Bool = true;
	public var worldCombo(default, set):Bool;

	public var scoreWarningText:FlxText;

	public var onSongStart:FlxTypedSignal<Void->Void> = new FlxTypedSignal<Void->Void>();
	public var onSongStartPost:FlxTypedSignal<Void->Void> = new FlxTypedSignal<Void->Void>();

	public var onSongEnd:FlxTypedSignal<Void->Void> = new FlxTypedSignal<Void->Void>();
	public var onSongEndPost:FlxTypedSignal<Void->Void> = new FlxTypedSignal<Void->Void>();

	public var onGameOver:FlxTypedSignal<GameOverEvent->Void> = new FlxTypedSignal<GameOverEvent->Void>();
	public var onGameOverPost:FlxTypedSignal<GameOverEvent->Void> = new FlxTypedSignal<GameOverEvent->Void>();

	#if SCRIPTING_ALLOWED
	public var scripts:FunkinScriptGroup;

	public var noteTypeScripts:Map<String, FunkinScript> = [];
	public var noteTypeScriptsArray:Array<FunkinScript> = []; // to avoid stupid for loop shit on maps, for convienience really

	public var eventScripts:Map<String, FunkinScript> = [];
	public var eventScriptsArray:Array<FunkinScript> = []; // to avoid stupid for loop shit on maps, for convienience really
	#end

	public function new(?params:PlayStateParams) {
		super();
		if(params == null)
			params = lastParams;

		currentSong = params.song;
		currentDifficulty = params.difficulty;

		currentMix = params.mix;
		if(currentMix == null || currentMix.length == 0)
			currentMix = "default";

		minimalMode = params.minimalMode ?? false;
		#if SCRIPTING_ALLOWED
		scriptsAllowed = params.scriptsAllowed ?? (!minimalMode);
		#end
		isStoryMode = params.isStoryMode ?? false;
		
		lastParams = params;
		instance = this;
	}

	override function create():Void {
		super.create();
		
		Logs.verbose('Loading into gameplay...');
		persistentUpdate = true;
		
		if(FlxG.sound.music != null)
			FlxG.sound.music.stop();

		final rawInstPath:String = Paths.sound('gameplay/songs/${currentSong}/${currentMix}/music/inst');
		if(lastParams.mod != null && lastParams.mod.length > 0)
			Paths.forceContentPack = lastParams.mod;
		else {
			final parentDir:String = '${Paths.getContentDirectory()}/';
			Paths.forceContentPack = null;

			if(rawInstPath.startsWith(parentDir))
				Paths.forceContentPack = Paths.getContentPackFromPath(rawInstPath);
		}
		if(lastParams._chart != null) {
			currentChart = lastParams._chart;
			lastParams._chart = null; // this is only useful for changing difficulties mid song, so we don't need to keep this value
		} else
			currentChart = ChartData.load(currentSong, currentMix, Paths.forceContentPack);
		
		final instPath:String = Paths.sound('gameplay/songs/${currentSong}/${currentMix}/music/inst');
		chartingMode = lastParams.chartingMode ?? false;

		camGame = new FunkinCamera();
		camGame.bgColor = 0;
		FlxG.cameras.reset(camGame);

		camHUD = new FunkinCamera();
		camHUD.bgColor = 0;
		FlxG.cameras.add(camHUD, false);

		camOther = new FunkinCamera();
		camOther.bgColor = 0;
		FlxG.cameras.add(camOther, false);
		
		Scoring.currentSystem = new PBotSystem(); // reset the scoring system, cuz you can change it thru scripting n shit, and that shouldn't persist
		
		final rawNoteSkin:String = currentChart.meta.game.noteSkin;
		final rawUISkin:String = currentChart.meta.game.uiSkin;
		final rawHUDSkin:String = currentChart.meta.game.hudSkin;
		
		var noteSkin:String = rawNoteSkin ?? "default";
		if(noteSkin == "default")
			currentChart.meta.game.noteSkin = noteSkin = Constants.DEFAULT_NOTE_SKIN;
		
		var uiSkin:String = rawUISkin ?? "default";
		if(uiSkin == "default")
			currentChart.meta.game.uiSkin = uiSkin = Constants.DEFAULT_UI_SKIN;

		var hudSkin:String = rawHUDSkin ?? "default";
		if(hudSkin == "default")
			currentChart.meta.game.hudSkin = hudSkin = Options.hudType;

		inline function now():Float {
			return System.getTimerPrecise();
		}
		var startTime:Float = now();
		inline function getElapsedTime():Float {
			return FlxMath.roundDecimal((now() - startTime) / 1000, 3);
		}
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed) {
			scripts = new FunkinScriptGroup();
			scripts.setParent(this);
			
			@:privateAccess
			final loaders:Array<AssetLoader> = Paths._registeredAssetLoaders;
			final oflAssetList:Array<String> = OpenFLAssets.list();
			
			inline function addScripts(loader:AssetLoader, dir:String) {
				final items:Array<String> = loader.readDirectory(dir);
				final scriptExts:Array<String> = Paths.ASSET_EXTENSIONS.get(SCRIPT);

				for(ass in oflAssetList) {
					ass = Path.normalize(ass);

					final dir2:String = Path.directory(ass);
					if(Path.normalize(Path.join([loader.root, dir])) != dir2)
						continue;

					items.push(Path.withoutDirectory(ass));
				}
				final contentMetadata:ContentMetadata = Paths.contentMetadata.get(loader.id);
				for(i in 0...items.length) {
					final path:String = Path.normalize(loader.getPath('${dir}/${items[i]}'));
					if(!scriptExts.contains('.${Path.extension(path)}'))
						continue;
					
					if(FlxG.assets.exists(path)) {
						final script:FunkinScript = FunkinScript.fromFile(path, contentMetadata?.allowUnsafeScripts ?? false);
						script.set("isCurrentPack", () -> return Paths.forceContentPack == loader.id);
						scripts.add(script);

						script.execute();
						script.call("new");
					}
				}
			}
			inline function addSingleScript(loader:AssetLoader, path:String) {
				final scriptPath:String = Paths.script(path, loader.id, false);
				final contentMetadata:ContentMetadata = Paths.contentMetadata.get(loader.id);

				if(FlxG.assets.exists(scriptPath)) {
					final script:FunkinScript = FunkinScript.fromFile(scriptPath, contentMetadata?.allowUnsafeScripts ?? false);
					script.set("isCurrentPack", () -> return Paths.forceContentPack == loader.id);
					scripts.add(script);

					script.execute();
					script.call("new");
				}
			}
			for(i in 0...loaders.length) {
				final loader:AssetLoader = loaders[i];
				final contentMetadata:ContentMetadata = Paths.contentMetadata.get(loader.id);

				if(contentMetadata == null || contentMetadata.runGlobally || Paths.forceContentPack == loader.id) {
					// gameplay scripts
					addScripts(loader, "gameplay/scripts"); // load any gameplay script first
					addScripts(loader, 'gameplay/songs/${currentSong}/scripts'); // then load from specific song, regardless of mix
					addScripts(loader, 'gameplay/songs/${currentSong}/${currentMix}/scripts'); // then load from specific song and specific mix
				}
				// noteskin script
				addSingleScript(loader, 'gameplay/noteskins/${noteSkin}/script');

				// uiskin script
				addSingleScript(loader, 'gameplay/uiskins/${uiSkin}/script');
			}
			scripts.call("onCreate");
		}
		Logs.verbose('- Loading scripts took ${getElapsedTime()}s');
		#end
		if(lastParams.startTime != null && lastParams.startTime > 0) {
			FlxTimer.wait((Conductor.instance.beatLength * 5) / 1000, () -> {
				Conductor.instance.time = -Conductor.instance.offset;
				Conductor.instance.autoIncrement = true;
				startSong();
			});
		}
		final songTracksToLoad:Array<AssetPreload> = [];
		songTracksToLoad.push({path: instPath, type: SOUND});
		scripts.call("onPreloadSong", [songTracksToLoad]);
		
		startTime = now();
		if(currentChart.meta.song.tracks != null) {
			final trackSet = currentChart.meta.song.tracks;
			final spectatorTrackPaths:Array<String> = [];
			for(track in trackSet.spectator) {
				final path:String = Paths.sound('gameplay/songs/${currentSong}/${currentMix}/music/${track}');
				spectatorTrackPaths.push(path);
				songTracksToLoad.push({path: path, type: SOUND});
			}
			final opponentTrackPaths:Array<String> = [];
			for(track in trackSet.opponent) {
				final path:String = Paths.sound('gameplay/songs/${currentSong}/${currentMix}/music/${track}');
				opponentTrackPaths.push(path);
				songTracksToLoad.push({path: path, type: SOUND});
			}
			final playerTrackPaths:Array<String> = [];
			for(track in trackSet.player) {
				final path:String = Paths.sound('gameplay/songs/${currentSong}/${currentMix}/music/${track}');
				playerTrackPaths.push(path);
				songTracksToLoad.push({path: path, type: SOUND});
			}
			Cache.preloadAssets(songTracksToLoad);

			vocals = new VocalGroup({
				spectator: spectatorTrackPaths,
				opponent: opponentTrackPaths,
				player: playerTrackPaths
			});
			add(vocals);
		} else {
			var chosenMainVocals:String = null;
			final vocalTrackPaths:Array<String> = [null, null, null];

			for(fileName in ['vocals', 'Vocals', 'voices', 'Voices']) {
				final localVocalTrackPaths:Array<String> = [
					Paths.sound('gameplay/songs/${currentSong}/${currentMix}/music/${fileName}-${currentChart.meta.game.characters.get("spectator")}'),
					Paths.sound('gameplay/songs/${currentSong}/${currentMix}/music/${fileName}-${currentChart.meta.game.characters.get("opponent")}'),
					Paths.sound('gameplay/songs/${currentSong}/${currentMix}/music/${fileName}-${currentChart.meta.game.characters.get("player")}')
				];
				for(i => path in localVocalTrackPaths) {
					if(FlxG.assets.exists(path))
						vocalTrackPaths[i] = path;
				}
				final mainVocals:String = Paths.sound('gameplay/songs/${currentSong}/${currentMix}/music/${fileName}');
				if(chosenMainVocals == null && FlxG.assets.exists(mainVocals)) {
					chosenMainVocals = mainVocals;
					songTracksToLoad.push({path: mainVocals, type: SOUND});
				}
			}
			for(path in vocalTrackPaths) {
				if(FlxG.assets.exists(path))
					songTracksToLoad.push({path: path, type: SOUND});
			}
			Cache.preloadAssets(songTracksToLoad);
	
			vocals = new VocalGroup({
				spectator: (FlxG.assets.exists(vocalTrackPaths[0])) ? [vocalTrackPaths[0]] : null,
				opponent: (FlxG.assets.exists(vocalTrackPaths[1])) ? [vocalTrackPaths[1]] : null,
				player: (FlxG.assets.exists(vocalTrackPaths[2])) ? [vocalTrackPaths[2]] : null,
				mainVocals: (FlxG.assets.exists(chosenMainVocals)) ? chosenMainVocals : null
			});
			add(vocals);
		}
		Logs.verbose('- Loading vocal tracks took ${getElapsedTime()}s');
		
		startTime = now();
		FlxG.sound.playMusic(instPath, 0, false);
		inst = FlxG.sound.music;
		Logs.verbose('- Loading inst took ${getElapsedTime()}s');

		Conductor.instance.music = null;
		Conductor.instance.offset = Options.songOffset + inst.latency;
		Conductor.instance.autoIncrement = (lastParams.startTime == null || lastParams.startTime <= 0);
		
		Conductor.instance.reset(currentChart.meta.song.timingPoints.first()?.bpm ?? 100.0);
		Conductor.instance.setupTimingPoints(currentChart.meta.song.timingPoints);
		
		Conductor.instance.time = -(Conductor.instance.beatLength * 5);

		WindowUtil.titlePrefix = (lastParams._unsaved) ? "* " : "";
		WindowUtil.titleSuffix = (chartingMode) ? " - Chart Playtesting" : "";

		inst.pause();
		inst.volume = 1;
		inst.onComplete = finishSong;

		final noteSkinData:NoteSkinData = NoteSkin.get(noteSkin);
		final uiSkinData:UISkinData = UISkin.get(uiSkin);
		
		final notesToPreload:Array<AssetPreload> = [];
		scripts.call("onPreloadNoteSkin", [notesToPreload]);
		
		notesToPreload.push({path: Paths.image('gameplay/noteskins/${noteSkin}/${noteSkinData.strum.atlas.path}'), type: IMAGE});
		notesToPreload.push({path: Paths.image('gameplay/noteskins/${noteSkin}/${noteSkinData.note.atlas.path}'), type: IMAGE});
		notesToPreload.push({path: Paths.image('gameplay/noteskins/${noteSkin}/${noteSkinData.splash.atlas.path}'), type: IMAGE});
		notesToPreload.push({path: Paths.image('gameplay/noteskins/${noteSkin}/${noteSkinData.hold.atlas.path}'), type: IMAGE});
		notesToPreload.push({path: Paths.image('gameplay/noteskins/${noteSkin}/${noteSkinData.holdCovers.atlas.path}'), type: IMAGE});
		notesToPreload.push({path: Paths.image('gameplay/noteskins/${noteSkin}/${noteSkinData.holdGradients.atlas.path}'), type: IMAGE});
		
		final uiToPreload:Array<AssetPreload> = [];
		scripts.call("onPreloadUISkin", [uiToPreload]);

		uiToPreload.push({path: Paths.image('gameplay/uiskins/${uiSkin}/${uiSkinData.rating.atlas.path}'), type: IMAGE});
		uiToPreload.push({path: Paths.image('gameplay/uiskins/${uiSkin}/${uiSkinData.combo.atlas.path}'), type: IMAGE});
		uiToPreload.push({path: Paths.image('gameplay/uiskins/${uiSkin}/${uiSkinData.countdown.atlas.path}'), type: IMAGE});
		
		if(!minimalMode) {
			final pendingCharacters:Array<String> = [];
			final charactersToLoad:Array<AssetPreload> = [];
			scripts.call("onPreloadCharacters", [charactersToLoad]);
			
			inline function preloadCharacter(character:String) {
				final data:CharacterData = CharacterData.load(character);

				if(!pendingCharacters.contains(character)) {
					charactersToLoad.push({path: Paths.image('gameplay/characters/${character}/${data.atlas.path}'), type: IMAGE});
					pendingCharacters.push(character);
				}
				if(data.deathCharacter != null && data.deathCharacter.length != 0) {
					if(!pendingCharacters.contains(data.deathCharacter)) {
						charactersToLoad.push({path: Paths.image('gameplay/characters/${data.deathCharacter}/${data.atlas.path}'), type: IMAGE});
						pendingCharacters.push(data.deathCharacter);
					}
				}
			}
			preloadCharacter(currentChart.meta.game.characters.get("spectator"));
			preloadCharacter(currentChart.meta.game.characters.get("opponent"));
			preloadCharacter(currentChart.meta.game.characters.get("player"));
			
			final stageData = StageData.load(currentChart.meta.game.stage);
			final stageAssetsToPreload:Array<AssetPreload> = [];
			scripts.call("onPreloadStage", [stageAssetsToPreload]);
			
			if(stageData.preload != null) {
				for(asset in stageData.preload) {
					switch(asset.type) {
						case IMAGE:
							asset.path = Paths.image('${stageData.getImageFolder()}/${asset.path}');
							
						case SOUND:
							asset.path = Paths.sound('${stageData.getSFXFolder()}/${asset.path}');
					}
					stageAssetsToPreload.push(asset);
				}
			}
			startTime = now();
			Cache.preloadAssets(charactersToLoad);
			Logs.verbose('- Loading characters took ${getElapsedTime()}s');
			
			Cache.preloadAssets(stageAssetsToPreload);
			Logs.verbose('- Loading stage took ${getElapsedTime()}s');

			final rawCharacterIDs:Array<String> = [
				currentChart.meta.game.getCharacter("spectator"),
				currentChart.meta.game.getCharacter("opponent"),
				currentChart.meta.game.getCharacter("player")
			];
			stage = new Stage(currentChart.meta.game.stage, {
				spectator: new Character(rawCharacterIDs[0], false),
				opponent: new Character(rawCharacterIDs[1], false),
				player: new Character(rawCharacterIDs[2], true)
			});
			camGame.zoom = stage.data.zoom;
			add(stage);
	
			spectator = stage.characters.spectator;
			opponent = stage.characters.opponent;
			player = stage.characters.player;

			if(rawCharacterIDs[1] == rawCharacterIDs[0]) {
				opponent.setPosition(spectator.x, spectator.y);
				opponent.scrollFactor.set(spectator.scrollFactor.x, spectator.scrollFactor.y);
				spectator.kill();
			}
			if(rawCharacterIDs[0] == null || rawCharacterIDs[0] == "none" || rawCharacterIDs[0].length == 0)
				spectator.kill();
		}
		else {
			final bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image("menus/bg_desat"));
			bg.color = 0xFF4CAF50;
			bg.screenCenter();
			bg.scrollFactor.set();
			add(bg);
		}
		eventRunner = new EventRunner(currentChart.events);
		eventRunner.onExecute.add(onEvent);
		eventRunner.onExecutePost.add(onEventPost);
		add(eventRunner);

		startTime = now();
		Cache.preloadAssets(notesToPreload.concat(uiToPreload));
		Logs.verbose('- Loading notes & UI took ${getElapsedTime()}s');

		startTime = now();
		final assetsToPreload:Array<AssetPreload> = [];
		scripts.call("onPreloadAssets", [assetsToPreload]);
		
		for(i in 0...4)
			assetsToPreload.push({path: Paths.sound('gameplay/sfx/missnote${i + 1}'), type: SOUND});
		
		Cache.preloadAssets(assetsToPreload);
		Logs.verbose('- Loading misc assets took ${getElapsedTime()}s');

		#if SCRIPTING_ALLOWED
		if(scriptsAllowed) {
			if(stage?.script != null) {
				scripts.add(stage.script);
				stage.script.setParent(stage);
				stage.script.set("this", stage);
				stage.script.call("onCreate");
			}
			for(character in [spectator, opponent, player]) {
				if(character?.script == null)
					continue;

				scripts.add(character.script);
				character.script.setParent(character);
				character.script.call("onCreate");
			}
			for(note in currentChart.notes.get(currentDifficulty)) {
				if(noteTypeScripts.exists(note.type))
					continue;
	
				final scriptPath:String = Paths.script('gameplay/notetypes/${note.type}');
				if(!FlxG.assets.exists(scriptPath))
					continue;
	
				final contentMetadata:ContentMetadata = Paths.contentMetadata.get(Paths.getContentPackFromPath(scriptPath));
				final script:FunkinScript = FunkinScript.fromFile(scriptPath, contentMetadata?.allowUnsafeScripts ?? false);
				script.set("NOTE_TYPE_ID", note.type);
				scripts.add(script);
	
				noteTypeScripts.set(note.type, script);
				noteTypeScriptsArray.push(script);

				script.execute();
				script.call("new");
				script.call("onCreate");
			}
			for(b in eventRunner.behaviors) {
				for(script in b.scripts.members) {
					scripts.add(script);
		
					eventScripts.set(b.eventType, script);
					eventScriptsArray.push(script);

					script.execute();
					script.call("new");
					script.call("onCreate");
				}
			}
		}
		#end
		for(e in eventRunner.events.filter((i) -> i.type == "Camera Pan")) {
			if(e.time > 10)
				break;

			eventRunner.execute(e);
		}
		final startingCamPos:Array<Float> = stage?.data.startingCamPos ?? [0.0, 0.0];
		camFollow = new FlxObject(startingCamPos[0], startingCamPos[1], 1, 1);
		add(camFollow);

		camGame.follow(camFollow, LOCKON, 0.05);
		camGame.snapToTarget();

		playField = new PlayField(currentChart, currentDifficulty);
		scripts.call("onGeneratePlayField", [playField]);
		
		playField.noteSpawner.onNoteSpawn.add(onNoteSpawn);
		playField.noteSpawner.onNoteSpawnPost.add(onNoteSpawnPost);
		
		playField.onNoteHit.add(onNoteHit);
		playField.onNoteHitPost.add(onNoteHitPost);

		playField.onNoteMiss.add(onNoteMiss);
		playField.onNoteMissPost.add(onNoteMissPost);

		playField.onDisplayRating.add(onDisplayRating);
		playField.onDisplayRatingPost.add(onDisplayRatingPost);

		playField.onDisplayCombo.add(onDisplayCombo);
		playField.onDisplayComboPost.add(onDisplayComboPost);

		playField.onUpdateStats.add(updateDiscordRPC);

		for(strumLine in playField.strumLines) {
			strumLine.onBotplayToggle.add((value:Bool) -> {
				if(strumLine == playField.playerStrumLine)
					onBotplayToggle(value);
			});
		}
		playField.strumLines.memberAdded.add(strumLineAdded);

		playField.cameras = [camHUD];
		add(playField);

		if(lastParams.forceOpponentMode != null)
			opponentMode = lastParams.forceOpponentMode;
		
		else if(Options.gameplayModifiers.get("opponentMode") == true && currentChart.meta.game.allowOpponentMode)
			opponentMode = true;
		
		scripts.call("onGeneratePlayFieldPost", [playField]);

		final event:HUDGenerationEvent = cast Events.get(HUD_GENERATION);
		event.recycle(hudSkin);

		#if SCRIPTING_ALLOWED
		if(scriptsAllowed) {
			scripts.event("onHUDGeneration", event);
			if(FlxG.assets.exists(Paths.script('gameplay/hudskins/${event.hudType}/script')))
				playField.hud = new ScriptedHUD(playField, event.hudType);
		}
		#end
		// check if it's null because it might've
		// already been initialized by the code directly above this
		if(playField.hud == null) {
			switch(event.hudType) {
				case "Classic+":
					playField.hud = new ClassicPlusHUD(playField);

				case "Psych":
					playField.hud = new PsychHUD(playField);
	
				default:
					playField.hud = new ClassicHUD(playField);
			}
		}
		playField.hud.cameras = [camHUD];
		add(playField.hud);
		
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed && playField.hud is ScriptedHUD) {
			final hud:ScriptedHUD = cast playField.hud;
			scripts.add(hud.script);
			
			hud.script.setParent(hud);
			hud.script.call("onCreate");

			scripts.onCall.add((m:String, a:Array<Dynamic>) -> hud.call(m, a));
		}
		#end
		countdown = new Countdown();
		countdown.onStart.add(onCountdownStart);
		countdown.onStartPost.add(onCountdownStartPost);

		countdown.onStep.add(onCountdownStep);
		countdown.onStepPost.add(onCountdownStepPost);

		countdown.cameras = [camHUD];
		add(countdown);

		if(!seenCutscene) {
			for(cutscene in startCutscenes)
				cutscene.onFinish.add(startNextCutscene);
			
			cutscene = startCutscenes.shift();
			if(cutscene != null) {
				camGame.followEnabled = false;
				camHUD.visible = false;
				Conductor.instance.autoIncrement = false;
	
				cutscene.start();
				add(cutscene);
			}
			seenCutscene = true;
		}
		if(!inCutscene)
			startCountdown();

		worldCombo = false;
		_saveScore = !(chartingMode ?? false);

		scoreWarningText = new FlxText(5, FlxG.height - 2, 0, "/!\\ - Player went into charting mode, score will not be saved", 16);
		scoreWarningText.setFormat(Paths.font("fonts/vcr"), 16, FlxColor.RED, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreWarningText.cameras = [camOther];
		scoreWarningText.visible = !_saveScore;
		scoreWarningText.y -= scoreWarningText.height;
		add(scoreWarningText);

		if(!isStoryMode) {
			practiceMode = Options.gameplayModifiers.get("practiceMode");
			playbackRate = Options.gameplayModifiers.get("playbackRate");
			playField.playerStrumLine.botplay = Options.gameplayModifiers.get("botplay");
		}
		DiscordRPC.changePresence("Starting song", "Gameplay");
	}

	override function createPost():Void {
		super.createPost();
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed)
			scripts.call("onCreatePost");
		#end
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		#if SCRIPTING_ALLOWED
		if(scriptsAllowed)
			scripts.call("onUpdate", [elapsed]);
		#end
		if(startingSong && Conductor.instance.time >= -Conductor.instance.offset)
			startSong();

		if(!_aboutToEndSong && FlxG.sound.music != null && FlxG.sound.music.length >= 1000 && FlxG.sound.music.time >= FlxG.sound.music.length - 1000) {
			// failsafe for if FlxSound doesn't decide to function
			_aboutToEndSong = true;
			FlxTimer.wait(1, () -> {
				if(!endingSong && _aboutToEndSong)
					finishSong();
			});
		}
		if(FlxG.keys.pressed.SHIFT && FlxG.keys.justPressed.END) {
			// TODO: warning for unsaved charts
			endSong(); // end the song immediately when SHIFT + END is pressed, as emergency
		}
		if(canPause && controls.justPressed.PAUSE)
			pause();

		if(controls.justPressed.RESET || (!practiceMode && canDie && playField.stats.health <= playField.stats.minHealth))
			gameOver();
		
		if(controls.justPressed.DEBUG)
			goToCharter();

		if(camGameZoomLerp > 0)
			camGame.extraZoom = FlxMath.lerp(camGame.extraZoom, 0.0, FlxMath.getElapsedLerp(camGameZoomLerp, elapsed));
		
		if(camHUDZoomLerp > 0)
			camHUD.extraZoom = FlxMath.lerp(camHUD.extraZoom, 0.0, FlxMath.getElapsedLerp(camHUDZoomLerp, elapsed));

		if(!minimalMode) {
			if(!isCameraOnForcedPos) {
				final cameraPos:FlxPoint = FlxPoint.get();
				switch(curCameraTarget) {
					case OPPONENT:
						opponent.getCameraPosition(cameraPos);
						cameraPos += stage.cameraOffsets.get("opponent");
		
					case PLAYER:
						player.getCameraPosition(cameraPos);
						cameraPos += stage.cameraOffsets.get("player");
		
					case SPECTATOR:
						spectator.getCameraPosition(cameraPos);
						cameraPos += stage.cameraOffsets.get("spectator");
				}
				var event:CameraMoveEvent = cast Events.get(CAMERA_MOVE);
				event.recycle(cameraPos);
				#if SCRIPTING_ALLOWED
				if(scriptsAllowed)
					scripts.event("onCameraMove", event);
				#end
				if(!event.cancelled)
					camFollow.setPosition(event.position.x, event.position.y);

				cameraPos.put();
			}
		}
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed)
			scripts.call("onUpdatePost", [elapsed]);
		#end
	}

	override function onFocusLost():Void {
		super.onFocusLost();

		if(!paused)
			pause();
		
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed)
			scripts.call("onFocusLost");
		#end
	}

	override function onFocus():Void {
		super.onFocus();
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed) {
			scripts.call("onFocus");
			scripts.call("onFocusGain");
			scripts.call("onFocusGained");
		}
		#end
	}

	override function startOutro(onOutroComplete:Void->Void):Void {
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed)
			scripts.call("onStartOutro");
		#end
		exitingState = true;
		super.startOutro(onOutroComplete);

		#if SCRIPTING_ALLOWED
		if(scriptsAllowed)
			scripts.call("onStartOutroPost");
		#end
	}

	override function onSubStateOpen(subState:FlxSubState):Void {
		super.onSubStateOpen(subState);
		if(_initialTransitionHappened || !(subState is TransitionSubState)) {
			paused = true;

			FlxTimer.wait(0.001, () -> {
				if(cutscene != null)
					cutscene.pause();
			});
			if(!(subState is GameOverSubState))
				camGame.followEnabled = false;
			
			Conductor.instance.music = null;
			Conductor.instance.autoIncrement = false;
			
			if(!(subState is TransitionSubState)) {
				if(!endingSong && FlxG.sound.music != null) {
					FlxG.sound.music.pause();
					vocals.pause();
				}
			}
		}
		_initialTransitionHappened = true;
		
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed) {
			scripts.call("onSubStateOpen", [subState]);
			scripts.call("onSubStateOpened", [subState]);
		}
		#end
	}

	override function onSubStateClose(subState:FlxSubState):Void {
		super.onSubStateClose(subState);

		if(!(subState is TransitionSubState)) {
			paused = false;
			
			final event:ActionEvent = Events.get(UNKNOWN).recycleBase();
			#if SCRIPTING_ALLOWED
			if(scriptsAllowed && subState is PauseSubState) {
				scripts.event("onResume", event);
				scripts.event("onGameResume", event);
			}
			#end
			if(!event.cancelled) {
				if(cutscene != null)
					cutscene.resume();

				if(!(subState is GameOverSubState))
					camGame.followEnabled = true;

				if(!inCutscene) {
					Conductor.instance.music = FlxG.sound.music;
					Conductor.instance.autoIncrement = true;
		
					if(!exitingState && !startingSong && FlxG.sound.music != null) {
						FlxG.sound.music.time = Conductor.instance.rawTime;
						FlxG.sound.music.resume();
		
						vocals.seek(FlxG.sound.music.time);
						vocals.resume();
					}
				}
				#if SCRIPTING_ALLOWED
				if(scriptsAllowed && subState is PauseSubState) {
					scripts.event("onResumePost", event);
					scripts.event("onGameResumePost", event);
				}
				#end
			}
		}
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed) {
			scripts.call("onSubStateClose", [subState]);
			scripts.call("onSubStateClosed", [subState]);
		}
		#end
	}

	public function getNoteSkinPreloads(noteSkin:String):Array<AssetPreload> {
		final noteSkinData:NoteSkinData = NoteSkin.get(noteSkin);
		final assetsToPreload:Array<AssetPreload> = [];
		assetsToPreload.push({path: Paths.image('gameplay/noteskins/${noteSkin}/${noteSkinData.strum.atlas.path}'), type: IMAGE});
		assetsToPreload.push({path: Paths.image('gameplay/noteskins/${noteSkin}/${noteSkinData.note.atlas.path}'), type: IMAGE});
		assetsToPreload.push({path: Paths.image('gameplay/noteskins/${noteSkin}/${noteSkinData.splash.atlas.path}'), type: IMAGE});
		assetsToPreload.push({path: Paths.image('gameplay/noteskins/${noteSkin}/${noteSkinData.hold.atlas.path}'), type: IMAGE});
		assetsToPreload.push({path: Paths.image('gameplay/noteskins/${noteSkin}/${noteSkinData.holdCovers.atlas.path}'), type: IMAGE});
		assetsToPreload.push({path: Paths.image('gameplay/noteskins/${noteSkin}/${noteSkinData.holdGradients.atlas.path}'), type: IMAGE});
		return assetsToPreload;
	}

	public function preloadNoteSkin(noteSkin:String):Array<AssetPreload> {
		final assetsToPreload:Array<AssetPreload> = getNoteSkinPreloads(noteSkin);
		Cache.preloadAssets(assetsToPreload);
		return assetsToPreload;
	}

	public function getUISkinPreloads(uiSkin:String):Array<AssetPreload> {
		final uiSkinData:UISkinData = UISkin.get(uiSkin);
		final assetsToPreload:Array<AssetPreload> = [];
		assetsToPreload.push({path: Paths.image('gameplay/uiskins/${uiSkin}/${uiSkinData.rating.atlas.path}'), type: IMAGE});
		assetsToPreload.push({path: Paths.image('gameplay/uiskins/${uiSkin}/${uiSkinData.combo.atlas.path}'), type: IMAGE});
		assetsToPreload.push({path: Paths.image('gameplay/uiskins/${uiSkin}/${uiSkinData.countdown.atlas.path}'), type: IMAGE});
		return assetsToPreload;
	}

	public function preloadUISkin(uiSkin:String):Array<AssetPreload> {
		final assetsToPreload:Array<AssetPreload> = getUISkinPreloads(uiSkin);
		Cache.preloadAssets(assetsToPreload);
		return assetsToPreload;
	}

	public function startNextCutscene():Void {
		final newCutscene:Cutscene = ((startingSong) ? startCutscenes : endCutscenes).shift();
		cutscene = newCutscene;
		
		if(cutscene == null) {
			camGame.followEnabled = true;
			camHUD.visible = true;
			Conductor.instance.autoIncrement = (lastParams.startTime == null || lastParams.startTime <= 0);

			inCutscene = false;
			startCountdown();
			return;
		}
		cutscene.start();
		add(cutscene);
	}

	public function gameOver():Void {
		final event:GameOverEvent = cast Events.get(GAME_OVER);
		onGameOver.dispatch(event.recycle());

		#if SCRIPTING_ALLOWED
		if(scriptsAllowed)
			scripts.event("onGameOver", event);
		#end
		if(event.cancelled)
			return;
		
		deathCounter++;
		camGame.followEnabled = true;

		Conductor.instance.music = null;
		Conductor.instance.autoIncrement = false;

		FlxG.sound.music.pause();
		vocals.pause();
		
		persistentUpdate = false;
		persistentDraw = false;
		openSubState(new GameOverSubState());

		onGameOverPost.dispatch(cast event.flagAsPost());
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed)
			scripts.event("onGameOverPost", event);
		#end
	}

	public function pause():Void {
		final event:ActionEvent = Events.get(UNKNOWN).recycleBase();
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed) {
			scripts.event("onPause", event);
			scripts.event("onGamePause", event);
		}
		#end
		if(event.cancelled)
			return;

		persistentUpdate = false;
		openSubState(new PauseSubState());

		#if SCRIPTING_ALLOWED
		if(scriptsAllowed) {
			scripts.event("onPausePost", event);
			scripts.event("onGamePausePost", event);
		}
		#end
	}

	public function startCountdown():Void {
		if(countdown != null)
			countdown.start(currentChart.meta.game.uiSkin);
	}

	public function startSong():Void {
		if(!startingSong)
			return;

		songLength = FlxG.sound.music.length;
		startingSong = false;
		
		onSongStart.dispatch();
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed) {
			scripts.call("onStartSong");
			scripts.call("onSongStart");
		}
		#end
		final hasStartTime:Bool = lastParams.startTime != null && lastParams.startTime > 0;
		if(hasStartTime)
			Conductor.instance.time = lastParams.startTime;
		else
			Conductor.instance.time = -Conductor.instance.offset;
		
		FlxG.sound.music.time = Conductor.instance.rawTime;
		FlxG.sound.music.resume();

		vocals.seek(Conductor.instance.rawTime);
		vocals.play();
		
		if(hasStartTime)
			playField.noteSpawner.skipToTime(Conductor.instance.rawTime);
		
		Conductor.instance.music = FlxG.sound.music;
		updateDiscordRPC(playField.stats);

		onSongStartPost.dispatch();
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed) {
			scripts.call("onStartSongPost");
			scripts.call("onSongStartPost");
		}
		#end
	}

	public function endSong():Void {
		if(endingSong)
			return;

		endingSong = true;
		seenCutscene = false;
		persistentUpdate = false;

		FlxTween.globalManager.forEach((tween:FlxTween) -> {
			tween.cancel();
		});
		FlxTimer.globalManager.forEach((timer:FlxTimer) -> {
			timer.cancel();
		});

		onSongEnd.dispatch();
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed) {
			scripts.call("onEndSong");
			scripts.call("onSongEnd");
		}
		#end
		if(_saveScore) {
			final recordID:String = Highscore.getScoreRecordID(
				currentSong, currentDifficulty, currentMix, null,
				Options.gameplayModifiers.get("opponentMode") == true && currentChart.meta.game.allowOpponentMode
			);
			Highscore.saveScoreRecord(recordID, {
				score: playField.stats.score,
				misses: playField.stats.misses,
				accuracy: playField.stats.accuracy,
				rank: Highscore.getRankFromStats(playField.stats),
				judges: playField.stats.judgements,
				version: Highscore.RECORD_VERSION
			});
			if(isStoryMode) {
				storyStats.score += playField.stats.score;
				storyStats.accuracyScore += playField.stats.accuracyScore;
				storyStats.totalNotesHit += playField.stats.totalNotesHit;
				
				for(judge => count in storyStats.judgements)
					storyStats.judgements.set(judge, count + playField.stats.judgements.get(judge));
				
				@:bypassAccessor storyStats.misses += playField.stats.misses;
				@:bypassAccessor storyStats.comboBreaks += playField.stats.comboBreaks;
			}
		}
		FlxG.sound.music.onComplete = null;

		Conductor.instance.music = null;
		Conductor.instance.autoIncrement = false;
		
		if(FlxG.sound.music.playing)
			vocals.pause();

		if(!lastParams.chartingMode) {
			if(isStoryMode) {
				if(storyPlaylist.length != 0) {
					TransitionableState.skipNextTransIn = true;
					TransitionableState.skipNextTransOut = true;
					
					PlayState.lastParams.song = storyPlaylist.shift();
					FlxG.switchState(PlayState.new.bind(PlayState.lastParams));
				} else {
					final recordID:String = Highscore.getLevelRecordID(storyLevel, currentDifficulty);
					Highscore.saveLevelRecord(recordID, {
						score: storyStats.score,
						misses: storyStats.misses,
						accuracy: storyStats.accuracy,
						rank: Highscore.getRankFromStats(storyStats),
						judges: storyStats.judgements,
						version: Highscore.RECORD_VERSION
					});
					FlxG.switchState(StoryMenuState.new);
					playExitMusic();
				}
			} else {
				FlxG.switchState(FreeplayState.new);
				playExitMusic();
			}
		} else
			goToCharter();
		
		onSongEndPost.dispatch();
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed) {
			scripts.call("onEndSongPost");
			scripts.call("onSongEndPost");
		}
		#end
	}

	public function updateDiscordRPC(stats:PlayerStats):Void {
		DiscordRPC.changePresence(
			'${currentChart.meta.song.title ?? currentSong} (${currentDifficulty.toUpperCase()})',
			'${stats.score} (${FlxMath.roundDecimal(stats.accuracy * 100, 2)}%) - ${stats.misses} miss${(stats.misses != 1) ? "es" : ""}'
		);
	}

	public function playExitMusic():Void {
		if(!Constants.PLAY_MENU_MUSIC_AFTER_EXIT) {
			if(!FlxG.sound.music.playing) {
				FlxG.signals.postStateSwitch.addOnce(() -> {
					FlxTimer.wait(0.001, () -> {
						FlxG.sound.music.time = 0;
						FlxG.sound.music.volume = 0;
						FlxG.sound.music.looped = true;
						FlxG.sound.music.play();
						FlxG.sound.music.fadeIn(0.16, 0, 1);
					});
				});
			}
		} else {
			final oldContentPack:String = Paths.forceContentPack;
			Paths.forceContentPack = null;
			CoolUtil.playMenuMusic();
			Paths.forceContentPack = oldContentPack;
		}
	}

	public function goToCharter():Void {
		persistentUpdate = false;
		camGame.followEnabled = false;
		
		FlxG.sound.music.pause();
		vocals.pause();
		
		FlxG.sound.music.onComplete = null;
		FlxG.switchState(ChartEditor.new.bind({
			song: currentSong,
			difficulty: currentDifficulty,
			mix: currentMix,
			mod: lastParams.mod,

			startTime: (lastParams.startTime != null && lastParams.startTime > 0) ? lastParams.startTime : null,

			_chart: currentChart,
			_unsaved: lastParams._unsaved
		}));
	}

	public function snapCamFollowToPos(x:Float = 0, y:Float = 0):Void {
		camFollow.setPosition(x, y);
		camGame.snapToTarget();
	}

	//----------- [ Private API ] -----------//
	
	private var _aboutToEndSong:Bool = false;

	@:unreflective
	private var _saveScore:Bool = true; // unreflective so you can't CHEAT in scripts >:[

	private function finishSong():Void {
		if(Conductor.instance.offset > 0) {
			// end the song after waiting for the amount
			// of time your song offset takes (in seconds),
			// to avoid the song ending too early
			FlxTimer.wait(Conductor.instance.offset / 1000, endSong);
		} else
			endSong();
	}

	private function onNoteSpawn(event:NoteSpawnEvent):Void {
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed) {
			final isPlayer:Bool = event.noteData.direction > Constants.KEY_COUNT - 1;
			final excludedScripts:Array<FunkinScript> = noteTypeScriptsArray;
			scripts.event("onNoteSpawn", event, excludedScripts);
			scripts.event((isPlayer) ? "onPlayerNoteSpawn" : "onOpponentNoteSpawn", event, excludedScripts);
			scripts.event((isPlayer) ? "goodNoteSpawn" : "dadNoteSpawn", event, excludedScripts);
	
			final noteTypeScript:FunkinScript = noteTypeScripts.get(event.noteType);
			if(noteTypeScript != null) {
				noteTypeScript.call("onNoteSpawn", [event]);
				noteTypeScript.call((isPlayer) ? "onPlayerNoteSpawn" : "onOpponentNoteSpawn", [event]);
				noteTypeScript.call((isPlayer) ? "goodNoteSpawn" : "dadNoteSpawn", [event]);
			}
		}
		#end
	}

	private function onNoteSpawnPost(event:NoteSpawnEvent):Void {
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed) {
			final isPlayer:Bool = event.note.strumLine == playField.getSecondStrumLine();
			final excludedScripts:Array<FunkinScript> = noteTypeScriptsArray;
			scripts.event("onNoteSpawnPost", event, excludedScripts);
			scripts.event((isPlayer) ? "onPlayerNoteSpawnPost" : "onOpponentNoteSpawnPost", event, excludedScripts);
			scripts.event((isPlayer) ? "goodNoteSpawnPost" : "dadNoteSpawnPost", event, excludedScripts);
	
			final noteTypeScript:FunkinScript = noteTypeScripts.get(event.noteType);
			if(noteTypeScript != null) {
				noteTypeScript.call("onNoteSpawnPost", [event]);
				noteTypeScript.call((isPlayer) ? "onPlayerNoteSpawnPost" : "onOpponentNoteSpawnPost", [event]);
				noteTypeScript.call((isPlayer) ? "goodNoteSpawnPost" : "dadNoteSpawnPost", [event]);
			}
		}
		#end
	}

	private function onNoteHit(event:NoteHitEvent):Void {
		final isPlayer:Bool = event.note.strumLine == playField.getSecondStrumLine();
		if(!minimalMode) {
			if(isPlayer)
				event.characters = [player];
			else
				event.characters = [opponent];
		} else
			event.characters = [];
		
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed) {
			final excludedScripts:Array<FunkinScript> = noteTypeScriptsArray;
			scripts.event("onNoteHit", event, excludedScripts);
			scripts.event((isPlayer) ? "onPlayerNoteHit" : "onOpponentNoteHit", event, excludedScripts);
			scripts.event((isPlayer) ? "onPlayerHit" : "onOpponentHit", event, excludedScripts);
			scripts.event((isPlayer) ? "goodNoteHit" : "dadNoteHit", event, excludedScripts);
	
			final noteTypeScript:FunkinScript = noteTypeScripts.get(event.noteType);
			if(noteTypeScript != null) {
				noteTypeScript.call("onNoteHit", [event]);
				noteTypeScript.call((isPlayer) ? "onPlayerNoteHit" : "onOpponentNoteHit", [event]);
				noteTypeScript.call((isPlayer) ? "onPlayerHit" : "onOpponentHit", [event]);
				noteTypeScript.call((isPlayer) ? "goodNoteHit" : "dadNoteHit", [event]);
			}
		}
		#end
		if(event.cancelled)
			return;
		
		if(event.unmuteVocals) {
			if(isPlayer) {
				for(track in vocals.player)
					track.muted = false;
			} else {
				for(track in vocals.opponent)
					track.muted = false;
			}
		}
		if(event.playSingAnim) {
			for(character in event.characters) {
				character.playSingAnim(event.direction, event.singAnimSuffix, true);
				character.holdTimer += event.length;
				character.holdingPose = event.note.strumLine == playField.playerStrumLine && !event.note.strumLine.botplay;
			}
		}
	}

	private function onNoteHitPost(event:NoteHitEvent):Void {
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed) {
			final isPlayer:Bool = event.note.strumLine == playField.getSecondStrumLine();
			final excludedScripts:Array<FunkinScript> = noteTypeScriptsArray;
			scripts.event("onNoteHitPost", event, excludedScripts);
			scripts.event((isPlayer) ? "onPlayerNoteHitPost" : "onOpponentNoteHitPost", event, excludedScripts);
			scripts.event((isPlayer) ? "onPlayerHitPost" : "onOpponentHitPost", event, excludedScripts);
			scripts.event((isPlayer) ? "goodNoteHitPost" : "dadNoteHitPost", event, excludedScripts);
	
			final noteTypeScript:FunkinScript = noteTypeScripts.get(event.noteType);
			if(noteTypeScript != null) {
				noteTypeScript.call("onNoteHitPost", [event]);
				noteTypeScript.call((isPlayer) ? "onPlayerNoteHitPost" : "onOpponentNoteHitPost", [event]);
				noteTypeScript.call((isPlayer) ? "onPlayerHitPost" : "onOpponentHitPost", [event]);
				noteTypeScript.call((isPlayer) ? "goodNoteHitPost" : "dadNoteHitPost", [event]);
			}
		}
		#end
	}
	
	private function onNoteMiss(event:NoteMissEvent):Void {
		final isPlayer:Bool = event.note.strumLine == playField.getSecondStrumLine();
		if(!minimalMode) {
			if(isPlayer)
				event.characters = [player];
			else
				event.characters = [opponent];
		} else
			event.characters = [];

		#if SCRIPTING_ALLOWED
		if(scriptsAllowed) {
			final excludedScripts:Array<FunkinScript> = noteTypeScriptsArray;
			scripts.event("onNoteMiss", event, excludedScripts);
			scripts.event((isPlayer) ? "onPlayerNoteMiss" : "onOpponentNoteMiss", event, excludedScripts);
			scripts.event((isPlayer) ? "onPlayerMiss" : "onOpponentMiss", event, excludedScripts);
			scripts.event((isPlayer) ? "goodNoteMiss" : "dadNoteMiss", event, excludedScripts);
	
			final noteTypeScript:FunkinScript = noteTypeScripts.get(event.noteType);
			if(noteTypeScript != null) {
				noteTypeScript.call("onNoteMiss", [event]);
				noteTypeScript.call((isPlayer) ? "onPlayerNoteMiss" : "onOpponentNoteMiss", [event]);
				noteTypeScript.call((isPlayer) ? "onPlayerMiss" : "onOpponentMiss", [event]);
				noteTypeScript.call((isPlayer) ? "goodNoteMiss" : "dadNoteMiss", [event]);
			}
		}
		#end
		if(event.cancelled)
			return;
		
		if(event.muteVocals) {
			if(isPlayer) {
				for(track in vocals.player)
					track.muted = true;
			} else {
				for(track in vocals.opponent)
					track.muted = true;
			}
		}
		if(event.playMissAnim) {
			for(character in event.characters) {
				character.playMissAnim(event.direction, event.missAnimSuffix, true);
				character.holdingPose = event.note.strumLine == playField.playerStrumLine && !event.note.strumLine.botplay;
			}
		}
	}

	private function onNoteMissPost(event:NoteMissEvent):Void {
		final isPlayer:Bool = event.note.strumLine == playField.getSecondStrumLine();
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed) {
			final excludedScripts:Array<FunkinScript> = noteTypeScriptsArray;
			scripts.event("onNoteMissPost", event, excludedScripts);
			scripts.event((isPlayer) ? "onPlayerNoteMissPost" : "onOpponentNoteMissPost", event, excludedScripts);
			scripts.event((isPlayer) ? "onPlayerMissPost" : "onOpponentMissPost", event, excludedScripts);
			scripts.event((isPlayer) ? "goodNoteMissPost" : "dadNoteMissPost", event, excludedScripts);
	
			final noteTypeScript:FunkinScript = noteTypeScripts.get(event.noteType);
			if(noteTypeScript != null) {
				noteTypeScript.call("onNoteMissPost", [event]);
				noteTypeScript.call((isPlayer) ? "onPlayerNoteMissPost" : "onOpponentNoteMissPost", [event]);
				noteTypeScript.call((isPlayer) ? "onPlayerMissPost" : "onOpponentMissPost", [event]);
				noteTypeScript.call((isPlayer) ? "goodNoteMissPost" : "dadNoteMissPost", [event]);
			}
		}
		#end
	}

	private function onEvent(event:SongEvent):Void {
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed)
			scripts.call("onEvent", [event]);
		#end
	}

	private function onEventPost(event:SongEvent):Void {
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed)
			scripts.call("onEventPost", [event]);
		#end
	}

	private function onDisplayRating(event:DisplayRatingEvent):Void {
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed)
			scripts.call("onDisplayRating", [event]);
		#end
	}

	private function onDisplayRatingPost(event:DisplayRatingEvent):Void {
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed)
			scripts.call("onDisplayRatingPost", [event]);
		#end
	}

	private function onDisplayCombo(event:DisplayComboEvent):Void {
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed)
			scripts.call("onDisplayCombo", [event]);
		#end
	}

	private function onDisplayComboPost(event:DisplayComboEvent):Void {
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed)
			scripts.call("onDisplayComboPost", [event]);
		#end
	}

	private function onCountdownStart(event:CountdownStartEvent):Void {
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed)
			scripts.call("onCountdownStart", [event]);
		#end
	}

	private function onCountdownStartPost(event:CountdownStartEvent):Void {
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed)
			scripts.call("onCountdownStartPost", [event]);
		#end
	}

	private function onCountdownStep(event:CountdownStepEvent):Void {
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed)
			scripts.call("onCountdownStep", [event]);
		#end
		if(event.cancelled)
			return;

		if(startingSong && playField.hud != null)
			playField.hud.bopIcons();
	}

	private function onCountdownStepPost(event:CountdownStepEvent):Void {
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed)
			scripts.call("onCountdownStepPost", [event]);
		#end
	}

	private function strumLineAdded(strumLine:StrumLine):Void {
		strumLine.onBotplayToggle.add((value:Bool) -> {
			if(strumLine == playField.playerStrumLine)
				onBotplayToggle(value);
		});
	}

	private function onBotplayToggle(value:Bool):Void {
		if(value && _saveScore) {
			_saveScore = false;
			if(scoreWarningText != null) {
				scoreWarningText.text = "/!\\ - Player activated botplay, score will not be saved";
				scoreWarningText.visible = true;
			}
		}
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed)
			scripts.call("onBotplayToggle", [value]);
		#end
	}

	override function stepHit(step:Int):Void {
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed)
			scripts.call("onStepHit", [step]);
		#end
	}

	override function beatHit(beat:Int):Void {
		var interval:Int = camZoomingInterval;
		if(interval < 0)
			interval = Conductor.instance.timeSignature.getNumerator();

		@:privateAccess
		final timingPoint:TimingPoint = Conductor.instance._latestTimingPoint;
		
		if(interval > 0 && beat > 0 && Math.floor(Conductor.instance.curDecBeat - timingPoint.beat) % interval == 0) {
			if(camGame.extraZoom < 0.25 * camZoomingIntensity) // stop camGame from zooming too much
				camGame.extraZoom += 0.015 * camZoomingIntensity;

			if(camHUD.extraZoom < 0.25 * camZoomingIntensity) // stop camHUD from zooming too much
				camHUD.extraZoom += 0.03 * camZoomingIntensity;
		}
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed)
			scripts.call("onBeatHit", [beat]);
		#end
	}

	override function measureHit(measure:Int):Void {
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed)
			scripts.call("onMeasureHit", [measure]);
		#end
	}

	//----------- [ Private API ] -----------//

	@:noCompletion
	private var _initialTransitionHappened:Bool = false;

	@:noCompletion
	private inline function get_songPercent():Float {
		return FlxMath.bound(Conductor.instance.rawTime / songLength, 0, 1);
	}

	@:noCompletion
	private inline function get_opponentStrumLine():StrumLine {
		return playField.opponentStrumLine;
	}

	@:noCompletion
	private inline function get_opponentStrums():StrumLine {
		return playField.opponentStrumLine;
	}

	@:noCompletion
	private inline function get_playerStrumLine():StrumLine {
		return playField.playerStrumLine;
	}

	@:noCompletion
	private inline function get_playerStrums():StrumLine {
		return playField.playerStrumLine;
	}

	@:noCompletion
	private inline function get_opponentMode():Bool {
		return playField.playerStrumLine == playField.getFirstStrumLine();
	}

	@:noCompletion
	private inline function set_opponentMode(newValue:Bool):Bool {
		playField.opponentStrumLine = (newValue) ? playField.getSecondStrumLine() : playField.getFirstStrumLine();
		playField.playerStrumLine = (newValue) ? playField.getFirstStrumLine() : playField.getSecondStrumLine();

		@:bypassAccessor playField.getFirstStrumLine().botplay = !newValue;
		@:bypassAccessor playField.getSecondStrumLine().botplay = newValue;

		return newValue;
	}

	@:noCompletion
	private function set_worldCombo(newValue:Bool):Bool {
		worldCombo = newValue;

		playField.comboDisplay.cameras = (worldCombo) ? [camGame] : [camHUD];
		playField.comboDisplay.legacyStyle = worldCombo;

		if(worldCombo) {
			playField.remove(playField.comboDisplay, true);
			
			final comboProp:ComboProp = cast stage.props.get("combo");
			comboProp.container.insert(comboProp.container.members.indexOf(comboProp) + 1, playField.comboDisplay);
			
			playField.comboDisplay.scrollFactor.set(comboProp.scrollFactor.x ?? 1.0, comboProp.scrollFactor.y ?? 1.0);
			playField.comboDisplay.setPosition(comboProp.x, comboProp.y);
		}
		else {
			playField.comboDisplay.container.remove(playField.comboDisplay, true);
			playField.insert(playField.members.indexOf(playField.playerStrumLine) + 1, playField.comboDisplay);
			
			playField.comboDisplay.scrollFactor.set();
			playField.comboDisplay.setPosition(FlxG.width * 0.474, (FlxG.height * 0.45) - 60); 
		}
		return worldCombo;
	}

	@:noCompletion
	private function set_practiceMode(newValue:Bool):Bool {
		practiceMode = newValue;

		if(practiceMode && _saveScore) {
			_saveScore = false;
			scoreWarningText.text = "/!\\ - Player activated practice mode, score will not be saved";
			scoreWarningText.visible = true;
		}
		return practiceMode;
	}

	@:noCompletion
	private function set_playbackRate(newValue:Float):Float {
		playbackRate = Math.max(newValue, 0.01);

		inst.pitch = playbackRate;
		vocals.setPitch(playbackRate);

		FlxG.timeScale = playbackRate;
		return playbackRate;
	}

	override function destroy() {
		#if SCRIPTING_ALLOWED
		if(scriptsAllowed) {
			scripts.call("onDestroy");
			scripts.close();
		}
		#end
		PlayState.instance = null;
		Paths.forceContentPack = null;

		Conductor.instance.music = null;
		Conductor.instance.autoIncrement = true;
		Conductor.instance.offset = 0;
		
		WindowUtil.resetTitle();
		WindowUtil.resetTitleAffixes();

		Scoring.currentSystem = new PBotSystem(); // reset the scoring system, cuz you can change it thru scripting n shit, and that shouldn't persist
		super.destroy();
	}
}

typedef PlayStateParams = {
	var song:String;
	var difficulty:String;

	/**
	 * Equivalent to song variants in V-Slice
	 */
	var ?mix:String;

	var ?mod:String;

	var ?isStoryMode:Bool;

	var ?chartingMode:Bool;

	var ?startTime:Float;

	var ?minimalMode:Bool;

	var ?scriptsAllowed:Bool;

	var ?forceOpponentMode:Bool;

	@:noCompletion
	var ?_chart:ChartData;

	@:noCompletion
	var ?_unsaved:Bool;
}