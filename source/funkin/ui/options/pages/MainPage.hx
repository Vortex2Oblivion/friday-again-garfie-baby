package funkin.ui.options.pages;

import flixel.util.FlxTimer;

import funkin.ui.AtlasText;
import funkin.states.menus.MainMenuState;
import funkin.states.menus.OptionsState;

class MainPage extends Page {
    public var pages:Array<PageData> = [
        {
            name: "Gameplay",
            menu: () -> new GameplayPage()
        },
        {
            name: "Appearance",
            menu: () -> new AppearancePage()
        },
        {
            name: "Miscellanous",
            menu: () -> new MiscellanousPage()
        },
        {
            name: "Controls",
            menu: () -> new ControlsPage()
        }
    ];
    public var curSelected:Int = 0;

    public var menuItems:FlxTypedSpriteContainer<AtlasText>;
    public var menuIcons:FlxSpriteContainer;

    override function create():Void {
        super.create();

        for(pack => customPages in Options.customPages) {
            for(page in customPages) {
                pages.push({
                    name: page,
                    menu: () -> new OptionPage('${pack}://${page}')
                });
            }
        }
        menuItems = new FlxTypedSpriteContainer<AtlasText>();
        add(menuItems);

        menuIcons = new FlxSpriteContainer();
        add(menuIcons);

        final iconSpacing:Float = 10;
        for(i => page in pages) {
            final item:AtlasText = new AtlasText(0, 90 * i, "bold", LEFT, page.name);
            item.alpha = 0.6;
            menuItems.add(item);
        }
        menuItems.screenCenter();
        menuItems.x -= 50 + (iconSpacing * 2);

        for(i => page in pages) {
            final item:AtlasText = menuItems.members[i];
            final icon:FlxSprite = new FlxSprite(item.x + menuItems.width + iconSpacing, item.y - 10);
            icon.loadGraphic(Paths.image('menus/options/category/${page.name.toLowerCase()}'));
            icon.setGraphicSize(100, 100);
            icon.updateHitbox();
            icon.alpha = 0.6;
            menuIcons.add(icon);
        }
        changeSelection(0, true);
    }

    override function update(elapsed:Float):Void {
        super.update(elapsed);

        final wheel:Float = MouseUtil.getWheel();
        if(controls.justPressed.UI_UP || wheel < 0)
            changeSelection(-1);

        if(controls.justPressed.UI_DOWN || wheel > 0)
            changeSelection(1);

        if(controls.justPressed.ACCEPT)
            FlxTimer.wait(0.001, () -> menu.loadPage(pages[curSelected].menu()));

        if(controls.justPressed.BACK) {
            Options.save();
            FlxG.switchState((OptionsState.lastParams.exitState != null) ? OptionsState.lastParams.exitState : MainMenuState.new);
            FlxG.sound.play(Paths.sound("menus/sfx/cancel"));
        }
    }

    public function changeSelection(by:Int = 0, ?force:Bool = false):Void {
        if(by == 0 && !force)
            return;

        curSelected = FlxMath.wrap(curSelected + by, 0, menuItems.length - 1);

        for(i => item in menuItems.members) {
            if(curSelected == i) {
                item.alpha = 1;
                menuIcons.members[i].alpha = 1;
            } else {
                item.alpha = 0.6;
                menuIcons.members[i].alpha = 0.6;
            }
        }
        FlxG.sound.play(Paths.sound("menus/sfx/scroll"));
    }
}

typedef PageData = {
    var name:String;
    var menu:Void->Page;
}