package shark.menus.options;

import flixel.FlxG;
import flixel.FlxState;
import flixel.util.FlxColor;
import shark.backend.Language;
import shark.menus.MainMenuState;
import shark.mobile.backend.Vibration;
import shark.modding.ModuleHandler;
import shark.ui.FlixelShark;
import shark.ui.debug.CrasherLog;
import shark.ui.views.OptionRow;
import shark.ui.views.OptionsView;

typedef OptionEntry = {
	labelKey:String,
	descriptionKey:String,
	getValue:Void->Bool,
	onToggle:Void->Bool
}

class OptionsState extends FlxState
{
	static inline var COLOR_ABYSS:FlxColor = 0xFF00111F;
	static inline var COLOR_DEEP:FlxColor = 0xFF012A4A;
	static inline var COLOR_MID:FlxColor = 0xFF01497C;

	var view:OptionsView;

	override public function create():Void
	{
		super.create();

		bgColor = COLOR_ABYSS;
		FlixelShark.createDepthGradient(this, [COLOR_ABYSS, COLOR_DEEP, COLOR_MID]);

		view = new OptionsView();
		add(view);

		view.titleLabel.text = Language.get("options.title");
		view.backButton.text = Language.get("menu.backButton");
		view.resetButton.text = Language.get("options.reset");

		view.backButton.onClick = _ -> goBack();
		view.resetButton.onClick = _ -> onResetPressed();

		for (entry in buildOptions())
			view.optionsList.addComponent(createToggleRow(entry));

		view.optionsList.addComponent(createLanguageRow());
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (FlxG.keys.justPressed.ESCAPE)
			goBack();
	}

	function buildOptions():Array<OptionEntry>
	{
		return [
			{
				labelKey: "options.fpsCounter",
				descriptionKey: "options.fpsCounterDescription",
				getValue: Main.isFpsCounterVisible,
				onToggle: Main.toggleFpsCounter
			},
			{
				labelKey: "options.vibration",
				descriptionKey: "options.vibrationDescription",
				getValue: () -> Main.settings.data.vibrationEnabled,
				onToggle: toggleVibration
			},
			{
				labelKey: "options.reducedMotion",
				descriptionKey: "options.reducedMotionDescription",
				getValue: () -> Main.settings.data.reducedMotion,
				onToggle: toggleReducedMotion
			},
			{
				labelKey: "options.devMode",
				descriptionKey: "options.devModeDescription",
				getValue: Main.isDevModeEnabled,
				onToggle: Main.toggleDevMode
			}
		];
	}

	function createToggleRow(entry:OptionEntry):OptionRow
	{
		var row:OptionRow = new OptionRow();

		row.nameLabel.text = Language.get(entry.labelKey);
		row.descriptionLabel.text = Language.get(entry.descriptionKey);
		row.toggle.selected = entry.getValue();
		row.toggle.onChange = function(_)
		{
			if (row.toggle.selected != entry.getValue())
				row.toggle.selected = entry.onToggle();
		};

		return row;
	}

	function createLanguageRow():OptionRow
	{
		var row:OptionRow = new OptionRow();

		row.nameLabel.text = Language.get("options.language");
		row.descriptionLabel.hidden = true;
		row.toggle.hidden = true;
		row.actionButton.hidden = false;
		row.actionButton.text = Language.getLanguageName(Language.current);
		row.actionButton.onClick = _ -> cycleLanguage();

		return row;
	}

	static function toggleVibration():Bool
	{
		var newValue:Bool = !Main.settings.data.vibrationEnabled;

		Main.settings.update(d -> d.vibrationEnabled = newValue);
		Vibration.setEnabled(newValue);

		return newValue;
	}

	static function toggleReducedMotion():Bool
	{
		var newValue:Bool = !Main.settings.data.reducedMotion;

		Main.settings.update(d -> d.reducedMotion = newValue);

		return newValue;
	}

	function cycleLanguage():Void
	{
		var languages:Array<String> = Language.supportedLanguages;
		var next:String = languages[(languages.indexOf(Language.current) + 1) % languages.length];

		Language.setLanguage(next);
		ModuleHandler.notifyLanguageChanged(next);

		FlixelShark.switchState(OptionsState.new, false);
	}

	function onResetPressed():Void
	{
		Main.settings.reset();
		Main.settings.forceSave();

		CrasherLog.addBreadcrumb("Settings reset to defaults", "settings");

		FlixelShark.switchState(OptionsState.new, false);
	}

	function goBack():Void
	{
		FlixelShark.switchState(MainMenuState.new, true, 0.4, COLOR_ABYSS);
	}
}
