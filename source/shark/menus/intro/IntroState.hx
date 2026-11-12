package shark.menus.intro;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import openfl.events.Event;
import openfl.media.Sound;
import openfl.media.SoundChannel;
import openfl.media.SoundTransform;
import openfl.utils.Assets;
import shark.ui.FlixelShark;
import shark.active.system.Body;
import shark.backend.localization.Language;
import shark.menus.MainMenuState;
import shark.mobile.backend.Vibration;
import shark.modding.ModuleHandler;
import shark.ui.debug.CrasherLog;

class IntroState extends FlxState
{
	static inline var MUSIC_PATH:String = "assets/sounds/intro/intro.mp3";
	static inline var MAX_DURATION_SECONDS:Float = 8;
	static inline var SKIP_PROMPT_DELAY_SECONDS:Float = 2;

	static inline var BODY_REVEAL_DELAY_SECONDS:Float = 0.3;
	static inline var TITLE_REVEAL_DELAY_SECONDS:Float = 0.9;
	static inline var TAGLINE_REVEAL_DELAY_SECONDS:Float = 1.6;

	static inline var COLOR_ABYSS:FlxColor = 0xFF00111F;
	static inline var COLOR_DEEP:FlxColor = 0xFF012A4A;
	static inline var COLOR_MID:FlxColor = 0xFF01497C;
	static inline var COLOR_FOAM:FlxColor = 0xFFE0FBFC;
	static inline var COLOR_ACCENT:FlxColor = 0xFF61A5C2;
	static inline var COLOR_KELP:FlxColor = 0xFF14746F;

	var body:Body;
	var titleText:FlxText;
	var taglineText:FlxText;
	var skipPromptText:FlxText;
	var soundChannel:SoundChannel;
	var elapsedSeconds:Float = 0;
	var hasAdvanced:Bool = false;
	var isMobile:Bool;

	var bubbles:Array<FlxSprite> = [];
	var kelpBlades:Array<{sprite:FlxSprite, offset:Float, speed:Float}> = [];

	override public function create():Void
	{
		super.create();

		isMobile = FlxG.onMobile;
		bgColor = COLOR_ABYSS;

		FlixelShark.createDepthGradient(this, [COLOR_ABYSS, COLOR_DEEP, COLOR_MID]);
		FlixelShark.createLightRays(this, isMobile ? 3 : 5, COLOR_FOAM);
		kelpBlades = FlixelShark.createKelpField(this, isMobile ? 4 : 7, COLOR_KELP);
		bubbles = FlixelShark.createBubbleField(this, isMobile ? 6 : 10, COLOR_ACCENT);

		body = new Body(FlxG.width / 2 - 35, FlxG.height / 2 - 130, 70);
		body.alpha = 0;
		body.scale.set(0.4, 0.4);
		add(body);

		titleText = FlixelShark.makeShadowText(0, FlxG.height / 2 - 10, FlxG.width, Language.get("app.name"), isMobile ? 42 : 34, COLOR_FOAM, COLOR_ACCENT,
			FlxTextAlign.CENTER);
		titleText.alpha = 0;
		add(titleText);

		taglineText = FlixelShark.makeText(0, titleText.y + titleText.height + 6, FlxG.width, Language.get("intro.tagline"), isMobile ? 16 : 14, COLOR_ACCENT,
			FlxTextAlign.CENTER);
		taglineText.alpha = 0;
		add(taglineText);

		skipPromptText = FlixelShark.makeText(0, FlxG.height - (isMobile ? 60 : 40), FlxG.width, Language.get("intro.tapToContinue"), isMobile ? 16 : 13,
			COLOR_ACCENT, FlxTextAlign.CENTER);
		skipPromptText.alpha = 0;
		add(skipPromptText);

		animateIn();
		playMusic();

		ModuleHandler.notifyIntroStart();
		CrasherLog.addBreadcrumb("Intro screen shown", "navigation");
	}

	function animateIn():Void
	{
		var reducedMotion:Bool = Main.settings != null && Main.settings.data.reducedMotion;

		if (reducedMotion)
		{
			body.alpha = 1;
			body.scale.set(1, 1);
			titleText.alpha = 1;
			taglineText.alpha = 1;
			skipPromptText.alpha = 0.8;
			return;
		}

		FlxTween.tween(body, {alpha: 1}, 0.6, {ease: FlxEase.quadOut, startDelay: BODY_REVEAL_DELAY_SECONDS});
		FlxTween.tween(body.scale, {x: 1, y: 1}, 0.6, {
			ease: FlxEase.elasticOut,
			startDelay: BODY_REVEAL_DELAY_SECONDS,
			onComplete: function(_):Void
			{
				body.reactToReplyReceived();
			}
		});

		FlxTween.tween(titleText, {alpha: 1}, 0.8, {ease: FlxEase.quadOut, startDelay: TITLE_REVEAL_DELAY_SECONDS});
		FlxTween.tween(taglineText, {alpha: 1}, 0.8, {ease: FlxEase.quadOut, startDelay: TAGLINE_REVEAL_DELAY_SECONDS});
		FlxTween.tween(skipPromptText, {alpha: 0.8}, 0.8, {ease: FlxEase.quadOut, startDelay: SKIP_PROMPT_DELAY_SECONDS});
	}

	function playMusic():Void
	{
		try
		{
			var sound:Sound = Assets.getSound(MUSIC_PATH);

			if (sound == null)
			{
				CrasherLog.logWarning('Intro music not found at "$MUSIC_PATH"', "audio");
				return;
			}

			var transform:SoundTransform = new SoundTransform(resolveVolume());
			soundChannel = sound.play(0, 0, transform);

			if (soundChannel != null)
				soundChannel.addEventListener(Event.SOUND_COMPLETE, onMusicComplete);
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('Failed to play intro music: ${Std.string(e)}', "audio");
		}
	}

	function resolveVolume():Float
	{
		if (Main.settings == null)
			return 0.7;

		return Main.settings.data.muted ? 0 : Main.settings.data.musicVolume;
	}

	function onMusicComplete(e:Event):Void
	{
		advance(false);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		FlixelShark.updateBubbleField(bubbles, elapsed);
		FlixelShark.updateKelpField(kelpBlades, elapsed);

		elapsedSeconds += elapsed;

		if (!hasAdvanced && elapsedSeconds >= MAX_DURATION_SECONDS)
		{
			advance(false);
			return;
		}

		if (elapsedSeconds >= SKIP_PROMPT_DELAY_SECONDS && wasSkipPressed())
			advance(true);
	}

	function wasSkipPressed():Bool
	{
		if (FlxG.keys.justPressed.ANY)
			return true;

		if (FlxG.mouse.justPressed)
			return true;

		return false;
	}

	function advance(skippedByUser:Bool):Void
	{
		if (hasAdvanced)
			return;

		hasAdvanced = true;

		Vibration.menuSelect();

		if (skippedByUser)
		{
			ModuleHandler.notifyIntroSkip();
			CrasherLog.addBreadcrumb("Intro screen skipped", "navigation");
		}
		else
		{
			CrasherLog.addBreadcrumb("Intro screen finished", "navigation");
		}

		stopMusic();
		ModuleHandler.notifyIntroComplete();

		FlixelShark.switchState(MainMenuState.new, true, 0.5, COLOR_ABYSS);
	}

	function stopMusic():Void
	{
		if (soundChannel == null)
			return;

		try
		{
			soundChannel.removeEventListener(Event.SOUND_COMPLETE, onMusicComplete);
			soundChannel.stop();
		}
		catch (e:Dynamic) {}

		soundChannel = null;
	}

	override public function destroy():Void
	{
		stopMusic();
		super.destroy();
	}
}
