package funkin.backend.macros;

import haxe.macro.*;
import haxe.macro.Context;
import haxe.macro.Expr;

class IncludeMacro {
    /**
     * Makes sure a bunch of extra classes get compiled into the
     * executable file, for scripting purposes.
     */
    public static function build():Array<Field> {
        #if macro
        final fields = Context.getBuildFields();
        final includes:Array<String> = [
            // OPENFL
            "openfl.system", "openfl.display", "openfl.geom", "openfl.media",

			// FLIXEL
			"flixel.util", "flixel.ui", "flixel.tweens", "flixel.tile", "flixel.text",
			"flixel.system", "flixel.sound", "flixel.path", "flixel.math", "flixel.input",
			"flixel.group", "flixel.graphics", "flixel.effects", "flixel.animation",
			
            // FLIXEL ADDONS
			"flixel.addons.api", "flixel.addons.display", "flixel.addons.effects", "flixel.addons.ui",
			"flixel.addons.plugin", "flixel.addons.text", "flixel.addons.tile", "flixel.addons.transition",
			"flixel.addons.util",

			// BASE HAXE
			"DateTools", "EReg", "Lambda", "StringBuf", "haxe.crypto", "haxe.display", "haxe.exceptions", "haxe.extern",

            // HAXEUI,
            "haxe.ui",

            // FUNKIN
            "funkin",

            // HAXELIBS
            "flxanimate",

			// LET'S GO GAMBLING!
			"sys"
		];
        final ignores:Array<String> = [
            // HAXEUI
            "haxe.ui.macros",
            
            // FLIXEL
            "flixel.system.macros",

            // HAXELIBS
            "flxanimate.format", "flxanimate.motion" 
        ];
        final isHashlink:Bool = Context.defined("hl");
        if(isHashlink) {
            // fixes FATAL ERROR : Failed to load function std@socket_set_broadcast
            ignores.push("sys.net.UdpSocket");
            ignores.push("openfl.net.DatagramSocket");

            // FATAL ERROR : Failed to load library sqlite.hdll
            ignores.push("sys.db");
            ignores.push("sys.ssl");
        } else {
            includes.push("openfl.net");
        }
        for(inc in includes)
			Compiler.include(inc, true, ignores);
        
        return fields;
        #else
        return [];
        #end
    }
}