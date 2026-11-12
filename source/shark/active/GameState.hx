package shark.active;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import shark.active.games.BubblePopState;
import shark.active.games.DeepDiveState;
import shark.active.games.ReefRunnerState;
import shark.active.games.SharkFeedFrenzyState;
import shark.backend.HighScores;
import shark.backend.Language;
import shark.menus.MainMenuState;
import shark.ui.FlixelShark;
import shark.ui.views.GameCard;
import shark.ui.views.GameSelectView;

typedef GameEntry = {
	id:String,
	titleKey:String,
	descriptionKey:String,
	icon:String,
	accentColor:FlxColor,
	createState:Void->FlxState
}

class GameState extends FlxState
{
	static inline var COLOR_ABYSS:FlxColor = 0xFF00111F;
	static inline var COLOR_DEEP:FlxColor = 0xFF012A4A;
	static inline var COLOR_MID:FlxColor = 0xFF01497C;
	static inline var COLOR_ACCENT:FlxColor = 0xFF61A5C2;
	static inline var COLOR_FOAM:FlxColor = 0xFFE0FBFC;
	static inline var COLOR_KELP:FlxColor = 0xFF14746F;
	static inline var COLOR_BUBBLE:FlxColor = 0xFF7FD8E8;
	static inline var COLOR_REEF:FlxColor = 0xFFEF9F76;
	static inline var COLOR_FISH:FlxColor = 0xFF52B788;

	static final GAMES:Array<GameEntry> = [
		{
			id: "bubble_pop",
			titleKey: "games.bubblePop",
			descriptionKey: "games.bubblePopDescription",
			icon: "o O o",
			accentColor: COLOR_BUBBLE,
			createState: BubblePopState.new
		},
		{
			id: "reef_runner",
			titleKey: "games.reefRunner",
			descriptionKey: "games.reefRunnerDescription",
			icon: ">>>",
			accentColor: COLOR_REEF,
			createState: ReefRunnerState.new
		},
		{
			id: "deep_dive",
			titleKey: "games.deepDive",
			descriptionKey: "games.deepDiveDescription",
			icon: "\\ /",
			accentColor: COLOR_ACCENT,
			createState: DeepDiveState.new
		},
		{
			id: "shark_feed_frenzy",
			titleKey: "games.sharkFeedFrenzy",
			descriptionKey: "games.sharkFeedFrenzyDescription",
			icon: "> <",
			accentColor: COLOR_FISH,
			createState: SharkFeedFrenzyState.new
		}
	];

	var view:GameSelectView;
	var bubbles:Array<FlxSprite> = [];
	var kelpBlades:Array<{sprite:FlxSprite, offset:Float, speed:Float}> = [];

	override public function create():Void
	{
		super.create();

		var isMobile:Bool = FlxG.onMobile;

		bgColor = COLOR_ABYSS;

		FlixelShark.createDepthGradient(this, [COLOR_ABYSS, COLOR_DEEP, COLOR_MID]);
		FlixelShark.createLightRays(this, isMobile ? 3 : 5, COLOR_FOAM);
		kelpBlades = FlixelShark.createKelpField(this, isMobile ? 4 : 7, COLOR_KELP);
		bubbles = FlixelShark.createBubbleField(this, isMobile ? 6 : 10, COLOR_ACCENT);

		view = new GameSelectView();
		add(view);

		view.titleLabel.text = Language.get("games.title");
		view.subtitleLabel.text = Language.get("games.subtitle");
		view.backButton.text = Language.get("menu.backButton");
		view.backButton.onClick = _ -> goBack();

		for (i in 0...GAMES.length)
			view.gameList.addComponent(createCard(GAMES[i], i * 0.1));
	}

	function createCard(entry:GameEntry, delay:Float):GameCard
	{
		var card:GameCard = new GameCard();
		var description:String = Language.get(entry.descriptionKey);
		var bestScore:Int = Std.int(HighScores.get(entry.id));

		if (bestScore > 0)
			description += "\n" + Language.get("games.bestScore", ["score" => Std.string(bestScore)]);

		card.iconBadge.text = entry.icon;
		card.iconBadge.backgroundColor = (entry.accentColor.rgb : Int);
		card.nameLabel.text = Language.get(entry.titleKey);
		card.descriptionLabel.text = description;
		card.playButton.text = Language.get("games.playButton");
		card.playButton.backgroundColor = (entry.accentColor.rgb : Int);
		card.playButton.onClick = _ -> FlixelShark.safeSwitchState(entry.createState);

		card.opacity = 0;
		FlxTween.tween(card, {opacity: 1}, 0.4, {ease: FlxEase.quadOut, startDelay: delay});

		return card;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		FlixelShark.updateBubbleField(bubbles, elapsed);
		FlixelShark.updateKelpField(kelpBlades, elapsed);

		if (FlxG.keys.justPressed.ESCAPE)
			goBack();
	}

	function goBack():Void
	{
		FlixelShark.safeSwitchState(MainMenuState.new);
	}
}
