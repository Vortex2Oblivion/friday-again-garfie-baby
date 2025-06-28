package funkin.gameplay.hud;

import flixel.ui.FlxBar;
import flixel.text.FlxText;
import flixel.util.FlxStringUtil;

import funkin.states.PlayState;

class ClassicHUD extends BaseHUD {
    public function new(playField:PlayField) {
        this.name = "Classic";
        super(playField);
    }

    public var healthBarBG:FlxSprite;
    public var healthBar:FlxBar;

    public var scoreText:FlxText;

    override function generateHealthBar():Void {
        final game:PlayState = PlayState.instance;
        final barY:Float = (Options.downscroll) ? 72 : FlxG.height * 0.9;

        healthBarBG = new FlxSprite(0, barY);
        healthBarBG.loadGraphic(Paths.image("gameplay/healthBar"));
        healthBarBG.screenCenter(X);
        add(healthBarBG);

        healthBar = new FlxBar(
            healthBarBG.x + 4, healthBarBG.y + 4,
            FlxBarFillDirection.RIGHT_TO_LEFT, Std.int(healthBarBG.width - 8), Std.int(healthBarBG.height - 8),
            null, null, playField.stats.minHealth, playField.stats.maxHealth
        );
        healthBar.createFilledBar(0xFFFF0000, 0xFF66FF33); // using direct 0xFF codes doesn't work in lua, must use FlxColor.fromString there instead
        healthBar.value = playField.stats.displayedHealth;
        healthBar.numDivisions = 0;
        add(healthBar);

        var opponentIcon = "face";
        if(game != null)
            opponentIcon = game.currentChart.meta.game.getCharacter("opponent");
        
        var playerIcon = "face";
        if(game != null)
            playerIcon = game.currentChart.meta.game.getCharacter("player");
        
        iconP2 = new HealthIcon(opponentIcon, 0);
        add(iconP2);

        iconP1 = new HealthIcon(playerIcon, 1);
        iconP1.flipX = !iconP1.flipX;
        add(iconP1);

        scoreText = new FlxText(healthBarBG.x + (healthBarBG.width - 190), healthBarBG.y + 30, 0, "Score: N/A");
        scoreText.setFormat(Paths.font("fonts/vcr"), 16, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        add(scoreText);
    }

    override function updateHealthBar() {
        final percent:Float = healthBar.value / healthBar.max;
        iconP2.health = 1 - percent;
        iconP1.health = percent;
        positionIcons();
    }

    override function updatePlayerStats(stats:PlayerStats):Void {
        if(playField.playerStrumLine.botplay)
            scoreText.text = "Botplay Enabled";
        else
            scoreText.text = "Score: " + FlxStringUtil.formatMoney(stats.score, false, true);
    }
    
    override function positionIcons():Void {
        final percent:Float = healthBar.value / healthBar.max;
        iconP1.x = healthBar.x + (healthBar.width * (1 - percent)) - 26;
        iconP1.y = healthBar.y + (healthBar.height * 0.5) - (iconP1.height * 0.5);
    
        iconP2.x = healthBar.x + (healthBar.width * (1 - percent)) - (iconP2.width - 26);
        iconP2.y = healthBar.y + (healthBar.height * 0.5) - (iconP2.height * 0.5);
    }
    
    override function update(elapsed:Float):Void {
        healthBar.setRange(playField.stats.minHealth, playField.stats.maxHealth);
        healthBar.value = FlxMath.lerp(healthBar.value, playField.stats.displayedHealth, FlxMath.getElapsedLerp(0.25, elapsed));

        positionIcons();
        super.update(elapsed);
    }

    override function bopIcons():Void {
        iconP2.bop();
        iconP1.bop();
        iconP1.bopTween.onUpdate = (_) -> {
            iconP1.updateHitbox();
            positionIcons();
        };
        positionIcons();
    }
    
    override function beatHit(beat:Int):Void {
        if(beat < 0)
            return;
        
        bopIcons();
    }
}