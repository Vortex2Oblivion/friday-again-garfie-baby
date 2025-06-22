package funkin.gameplay.hud;

import flixel.graphics.frames.FlxAtlasFrames;
import funkin.backend.Conductor.IBeatReceiver;

class BaseHUD extends FlxGroup implements IBeatReceiver {
    public var name:String;
    public var playField:PlayField;
    
    public var iconP2:HealthIcon;
    public var iconP1:HealthIcon;

    public function new(playField:PlayField) {
        super();
        this.playField = playField;
        
        generateHealthBar();
        updateHealthBar();

        generatePlayerStats();
        updatePlayerStats(playField.stats);
    }

    public function call(method:String, ?args:Array<Dynamic>):Void {
        if(args == null)
            args = [];

        final func:Dynamic = Reflect.field(this, method);
        if(func != null && Reflect.isFunction(func))
            func(args);
    }

    public function getHUDImage(name:String):String {
        return Paths.image('gameplay/hudskins/${this.name}/images/${name}');
    }

    public function getHUDAtlas(name:String):FlxAtlasFrames {
        return Paths.getSparrowAtlas('gameplay/hudskins/${this.name}/images/${name}');
    }

    public function generateHealthBar():Void {}
    public function generatePlayerStats():Void {}
    
    public function updateHealthBar():Void {}
    
    public function bopIcons():Void {}
    public function positionIcons():Void {}

    public function updatePlayerStats(stats:PlayerStats):Void {}

    public function stepHit(step:Int) {}
    public function beatHit(beat:Int) {}
    public function measureHit(measure:Int) {}
}