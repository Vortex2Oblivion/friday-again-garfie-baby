package funkin.ui.menubar;

class MenuBarTextbox extends UIComponent {
    public var bg:FlxSprite;
    public var textbox:Textbox;
    public var valueFactory:Void->String;

    public function new(x:Float = 0, y:Float = 0, text:String, ?maxCharacters:Int = 0, ?autoSize:Bool = false, ?width:Float = 100, ?callback:String->Void, ?valueFactory:Void->String) {
        super(x, y);
        this.valueFactory = valueFactory;

        bg = new FlxSprite().loadGraphic(Paths.image("ui/images/top_bar"));
        bg.visible = false;
        add(bg);

        textbox = new Textbox(4, 2, text, autoSize, width, 22, callback);
        textbox.maxCharacters = maxCharacters;
        add(textbox);

        bg.setGraphicSize(textbox.width + 12, bg.frameHeight);
        bg.updateHitbox();
    }

    override function update(elapsed:Float):Void {
        if(!textbox.typing && valueFactory != null)
            textbox.text = valueFactory();

        super.update(elapsed);

        bg.setGraphicSize(textbox.width + 12, bg.frameHeight);
        bg.updateHitbox();
    }
}