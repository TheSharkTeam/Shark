package shark.ui.debug.menu;

import flixel.FlxG;
import flixel.FlxState;
import flixel.util.FlxColor;
import haxe.ui.components.Button;
import shark.graphics.ProceduralGraphics;
import shark.menus.MainMenuState;
import shark.mobile.backend.Vibration;
import shark.mobile.backend.Vibration.HapticStyle;
import shark.modding.api.ModVersion;
import shark.ui.debug.CrasherLog;
import shark.ui.debug.chat.ChatEditorState;
import shark.ui.views.DebugMenuView;

typedef DebugMenuEntry = {
	label:String,
	description:String,
	createState:Void->FlxState,
	enabled:Bool
}

class DebugMenuState extends FlxState
{
	var view:DebugMenuView;

	override function create():Void
	{
		super.create();

		add(ProceduralGraphics.makeGradientSprite(0, 0, FlxG.width, FlxG.height, FlxColor.fromRGB(10, 18, 28), FlxColor.fromRGB(4, 8, 14)));

		view = new DebugMenuView();
		add(view);

		view.statusLabel.text = 'Mod API ${ModVersion.CURRENT}${Main.isSafeMode ? " - SAFE MODE" : ""}';
		view.backButton.onClick = _ -> goBack();

		for (entry in buildEntries())
			view.entryList.addComponent(createEntryButton(entry));

		CrasherLog.addBreadcrumb("Opened debug menu (editor mode)", "navigation");
	}

	function buildEntries():Array<DebugMenuEntry>
	{
		return [
			{
				label: "Chat Editor",
				description: "Edit chat prompts, history, and live API settings.",
				createState: ChatEditorState.new,
				enabled: true
			}
		];
	}

	function createEntryButton(entry:DebugMenuEntry):Button
	{
		var button:Button = new Button();

		button.text = '${entry.label}\n${entry.description}';
		button.percentWidth = 100;
		button.disabled = !entry.enabled;
		button.onClick = _ -> openEntry(entry);

		return button;
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (FlxG.keys.justPressed.ESCAPE)
			goBack();
	}

	function openEntry(entry:DebugMenuEntry):Void
	{
		try
		{
			CrasherLog.addBreadcrumb('Opened editor: ${entry.label}', "navigation");
			Vibration.trigger(HapticStyle.MEDIUM);
			FlxG.switchState(entry.createState);
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('Failed to open debug menu entry "${entry.label}": ${Std.string(e)}', "editor");
			view.messageLabel.text = '${entry.label} failed to open.';
			Vibration.trigger(HapticStyle.FAILURE);
		}
	}

	function goBack():Void
	{
		Vibration.menuSelect();
		CrasherLog.addBreadcrumb("Left debug menu", "navigation");
		FlxG.switchState(MainMenuState.new);
	}

	public static function open():Void
	{
		FlxG.switchState(DebugMenuState.new);
	}
}
