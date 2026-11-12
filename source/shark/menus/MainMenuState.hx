package shark.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.graphics.FlxGraphic;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import haxe.ui.Toolkit;
import haxe.ui.components.Image;
import haxe.ui.components.Label;
import openfl.display.BitmapData;
import shark.active.GameState;
import shark.active.system.Body;
import shark.active.system.BodyState;
import shark.active.system.Head;
import shark.audio.Audio;
import shark.backend.localization.Language;
import shark.backend.assets.Paths;
import shark.functions.ChatEngine;
import shark.menus.options.OptionsState;
import shark.mobile.ui.AndroidKeyboard;
import shark.modding.ModuleHandler;
import shark.native.MainCpp;
import shark.online.Online;
import shark.online.manager.Internet;
import shark.shaders.WaterShader;
import shark.shaders.WaterShader.IUpdatableShader;
import shark.system.Boost;
import shark.system.PerformanceManager;
import shark.ui.FlixelShark;
import shark.ui.debug.menu.DebugMenuState;
import shark.ui.views.MainMenuView;

enum abstract MessageKind(String) to String
{
	var USER = "message-user";
	var SHARK = "message-shark";
	var ERROR = "message-error";
}

class MainMenuState extends FlxState
{
	static inline var COLOR_ABYSS:FlxColor = 0xFF00111F;
	static inline var COLOR_DEEP:FlxColor = 0xFF012A4A;
	static inline var COLOR_MID:FlxColor = 0xFF01497C;
	static inline var COLOR_WAVE:FlxColor = 0xFF2C7DA0;
	static inline var COLOR_ACCENT:FlxColor = 0xFF61A5C2;
	static inline var COLOR_FOAM:FlxColor = 0xFFE0FBFC;
	static inline var COLOR_KELP:FlxColor = 0xFF14746F;

	static inline var LATENCY_REFRESH_INTERVAL:Float = 15;
	static inline var MAX_IMAGE_WIDTH:Float = 320;

	var view:MainMenuView;
	var body:Body;
	var waterShader:IUpdatableShader;

	var kelpBlades:Array<{sprite:FlxSprite, offset:Float, speed:Float}> = [];
	var bubbles:Array<FlxSprite> = [];

	var isMobile:Bool;
	var thinkingElapsed:Float = 0;
	var latencyRefreshTimer:Float = 0;

	override public function create():Void
	{
		super.create();

		isMobile = FlxG.onMobile;
		bgColor = COLOR_ABYSS;

		createBackground();

		body = new Body(0, 0, 70);

		view = new MainMenuView();
		add(view);
		add(body);

		setupView();

		Internet.addListener(onOnlineStatusChanged);
		AndroidKeyboard.initialize();
		AndroidKeyboard.onKeyboardVisibilityChanged = onSoftKeyboardVisibilityChanged;
		onOnlineStatusChanged(Internet.isConnected);

		Head.onThinkingChanged = onThinkingChanged;
		Head.onNavigate = onNavigateRequest;

		restoreHistory();

		if (view.historyList.numComponents == 0)
			appendMessage(Language.get("app.name"), Head.getWelcomeMessage(), SHARK);

		if (Paths.exists(Paths.music("ocean_ambient")))
			Audio.playMusic("ocean_ambient");
	}

	function createBackground():Void
	{
		FlixelShark.createDepthGradient(this, [COLOR_ABYSS, COLOR_DEEP, COLOR_MID]);
		FlixelShark.createLightRays(this, isMobile ? 3 : 5, COLOR_FOAM);

		waterShader = WaterShader.createForCurrentDevice();

		var waveColors:Array<FlxColor> = [COLOR_MID, COLOR_WAVE, COLOR_ACCENT];

		for (i in 0...waveColors.length)
		{
			var wave:FlxSprite = FlixelShark.makeStaticSprite(0, FlxG.height - 40 - (i * 30), FlxG.width, 60, waveColors[i], 0.22);

			if (waterShader != null)
				wave.shader = cast waterShader;

			add(wave);
			FlxTween.tween(wave, {x: -40}, 3 + i, {ease: FlxEase.sineInOut, type: PINGPONG});
		}

		kelpBlades = FlixelShark.createKelpField(this, isMobile ? 5 : 8, COLOR_KELP);
		bubbles = FlixelShark.createBubbleField(this, isMobile ? 8 : 14, COLOR_ACCENT);
	}

	function setupView():Void
	{
		Boost.initialize();

		view.titleLabel.text = Language.get("menu.title");
		view.newChatButton.text = Language.get("menu.newChatButton");
		view.optionsButton.text = Language.get("menu.optionsButton");
		view.gamesButton.text = Language.get("menu.gamesButton");
		view.boostButton.text = Language.get("menu.boostButton");
		view.sendButton.text = Language.get("menu.sendButton");
		view.versionLabel.text = 'v${PerformanceManager.buildVersion}';

		refreshMuteButton(Audio.isMuted);
		refreshBoostButton(Boost.isBoostActive);

		view.muteButton.onClick = _ -> onMutePressed();
		view.newChatButton.onClick = _ -> onNewChatPressed();
		view.optionsButton.onClick = _ -> FlixelShark.switchState(OptionsState.new, true, 0.4, COLOR_ABYSS);
		view.gamesButton.onClick = _ -> goToGameState();
		view.boostButton.onClick = _ -> refreshBoostButton(Boost.toggleBoost());
		view.sendButton.onClick = _ -> submitInput();
		view.inputField.onChange = _ -> refreshInputHints();

		if (Main.isDevModeActive())
		{
			view.debugButton.hidden = false;
			view.debugButton.onClick = _ -> FlixelShark.switchState(DebugMenuState.new, true, 0.4, COLOR_ABYSS);
		}

		#if SHARK_DEV_MODE
		view.devWatermark.text = 'Dev Build (Commit: ${MainCpp.BUILD_COMMIT})';
		view.devWatermark.hidden = false;
		#end

		refreshInputHints();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		FlixelShark.updateBubbleField(bubbles, elapsed);
		FlixelShark.updateKelpField(kelpBlades, elapsed);

		if (waterShader != null)
			waterShader.update(elapsed);

		body.setPosition(view.avatarSpacer.screenLeft, view.avatarSpacer.screenTop);

		if (Head.isThinking)
		{
			thinkingElapsed += elapsed;
			view.thinkingLabel.text = Language.get("menu.thinking") + StringTools.rpad("", ".", Std.int(thinkingElapsed * 2) % 4);
		}

		if (!isMobile && FlxG.keys.justPressed.ENTER)
			submitInput();

		if (Internet.isConnected)
		{
			latencyRefreshTimer += elapsed;

			if (latencyRefreshTimer >= LATENCY_REFRESH_INTERVAL)
			{
				latencyRefreshTimer = 0;
				refreshStatusText();
			}
		}
	}

	function restoreHistory():Void
	{
		ChatEngine.loadHistory();

		for (entry in ChatEngine.getHistory())
		{
			var isUser:Bool = entry.role == "user";
			appendMessage(isUser ? Language.get("chat.you") : Language.get("app.name"), entry.content, isUser ? USER : SHARK);
		}
	}

	function submitInput():Void
	{
		var message:String = view.inputField.text;

		if (message == null || StringTools.trim(message).length == 0 || view.sendButton.disabled)
			return;

		sendMessage(message);
		FlixelShark.pulse(view.sendButton, 0.08, 0.15);
	}

	function sendMessage(message:String):Void
	{
		appendMessage(Language.get("chat.you"), message, USER);
		view.inputField.text = "";
		refreshInputHints();

		body.reactToMessageSent();
		ModuleHandler.notifyMessageSent(message);

		if (!isChatConfigured() && !isLocalCommand(message))
		{
			var reason:String = Main.isNetworkConfigTrusted ? Language.get("chat.notConfigured") : Language.get("chat.blockedEndpoint");

			appendMessage(Language.get("app.name"), reason, SHARK);
			body.reactToError();
			return;
		}

		Audio.play("message_send");
		view.sendButton.disabled = true;

		Head.think(message, onReply, onError, onImageGenerated, onImageError);
	}

	function isLocalCommand(message:String):Bool
	{
		var trimmed:String = StringTools.trim(message);

		return StringTools.startsWith(trimmed, "/") || StringTools.startsWith(trimmed, "!");
	}

	function isChatConfigured():Bool
	{
		return StringTools.trim(ChatEngine.endpoint).length > 0;
	}

	function onReply(reply:String):Void
	{
		appendMessage(Language.get("app.name"), reply, SHARK);
		Audio.play("message_receive");
		refreshSendButton();
		body.reactToReplyReceived();
		ModuleHandler.notifyReplyReceived(reply);
	}

	function onError(error:String):Void
	{
		appendMessage("Error", error, ERROR);
		refreshSendButton();
		body.reactToError();
		ModuleHandler.notifyError(error);
	}

	function onImageGenerated(bitmap:BitmapData):Void
	{
		var image:Image = new Image();
		var scale:Float = Math.min(1, MAX_IMAGE_WIDTH / bitmap.width);

		image.resource = FlxGraphic.fromBitmapData(bitmap).imageFrame.frame;
		image.width = bitmap.width * scale;
		image.height = bitmap.height * scale;

		appendMessage(Language.get("app.name"), Language.get("chat.imageGenerated"), SHARK);
		view.historyList.addComponent(image);
		scrollHistoryToBottom();

		Audio.play("message_receive");
		body.reactToReplyReceived();
		ModuleHandler.notifyImageGenerated();
	}

	function onImageError(error:String):Void
	{
		appendMessage("Error", "generating image: " + error, ERROR);
		body.reactToError();
	}

	function onMutePressed():Void
	{
		refreshMuteButton(Audio.toggleMute());
		FlixelShark.pulse(view.muteButton, 0.08, 0.15);
	}

	function onNewChatPressed():Void
	{
		Head.reset();

		view.historyList.removeAllComponents();
		appendMessage(Language.get("app.name"), Head.getWelcomeMessage(), SHARK);

		FlixelShark.pulse(view.newChatButton, 0.08, 0.15);
	}

	function onNavigateRequest(destination:String):Void
	{
		if (destination == "games")
			goToGameState();
	}

	function goToGameState():Void
	{
		FlixelShark.switchState(GameState.new, true, 0.4, COLOR_ABYSS);
	}

	function refreshMuteButton(muted:Bool):Void
	{
		view.muteButton.text = Language.get(muted ? "menu.unmuteButton" : "menu.muteButton");
	}

	function refreshBoostButton(active:Bool):Void
	{
		if (active)
			view.boostButton.addClass("active");
		else
			view.boostButton.removeClass("active");
	}

	function refreshSendButton():Void
	{
		view.sendButton.disabled = !Internet.isConnected || Head.isThinking;
	}

	function refreshStatusText():Void
	{
		Internet.measureLatency(_ -> view.statusLabel.text = '${Internet.getStatusLabel()} (${Online.getStabilityLabel()})');
	}

	function refreshInputHints():Void
	{
		var text:String = view.inputField.text != null ? view.inputField.text : "";
		var length:Int = text.length;
		var max:Int = ChatEngine.maxMessageLength;

		view.charCounterLabel.text = '$length/$max';
		view.charCounterLabel.removeClasses(["warning", "error"]);

		if (length >= max)
			view.charCounterLabel.addClass("error");
		else if (length >= Std.int(max * 0.9))
			view.charCounterLabel.addClass("warning");

		view.commandHintLabel.text = commandHintFor(StringTools.trim(text));
	}

	function commandHintFor(trimmed:String):String
	{
		if (!isLocalCommand(trimmed))
			return "";

		var spaceIndex:Int = trimmed.indexOf(" ");
		var typed:String = (spaceIndex == -1 ? trimmed : trimmed.substr(0, spaceIndex)).toLowerCase();

		return [for (command in Head.getAvailableCommands()) if (StringTools.startsWith(command, typed)) command].join("  ");
	}

	function onSoftKeyboardVisibilityChanged(visible:Bool):Void
	{
		if (isMobile)
			view.paddingBottom = visible ? FlxG.height * 0.35 : 12;
	}

	function onOnlineStatusChanged(online:Bool):Void
	{
		view.statusLabel.text = Internet.getStatusLabel();
		view.statusLabel.styleNames = online ? "status-online" : "status-offline";

		refreshSendButton();

		if (online)
		{
			latencyRefreshTimer = 0;
			refreshStatusText();
		}
	}

	function onThinkingChanged(thinking:Bool):Void
	{
		thinkingElapsed = 0;
		body.setState(thinking ? THINKING : IDLE);

		if (!thinking)
			view.thinkingLabel.text = "";

		refreshSendButton();
	}

	function appendMessage(speaker:String, text:String, kind:MessageKind):Void
	{
		var label:Label = new Label();

		label.text = '$speaker: $text';
		label.styleNames = 'message $kind';
		label.percentWidth = 100;

		view.historyList.addComponent(label);
		scrollHistoryToBottom();
	}

	function scrollHistoryToBottom():Void
	{
		Toolkit.callLater(() -> view.historyScroll.vscrollPos = view.historyScroll.vscrollMax);
	}

	override public function destroy():Void
	{
		Internet.removeListener(onOnlineStatusChanged);

		if (Head.onThinkingChanged == onThinkingChanged)
			Head.onThinkingChanged = null;

		super.destroy();
	}
}
