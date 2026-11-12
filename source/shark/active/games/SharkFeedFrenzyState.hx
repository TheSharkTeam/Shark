package shark.active.games;

import flixel.FlxState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import shark.backend.HighScores;

typedef FallingItem = {sprite:FlxSprite, isFish:Bool}

class SharkFeedFrenzyState extends FlxState
{
	static inline var GAME_ID:String = "shark_feed_frenzy";

	static inline var COLOR_ABYSS:FlxColor = 0xFF00111F;
	static inline var COLOR_ACCENT:FlxColor = 0xFF61A5C2;
	static inline var COLOR_FOAM:FlxColor = 0xFFE0FBFC;
	static inline var COLOR_DANGER:FlxColor = 0xFFF87171;
	static inline var COLOR_FISH:FlxColor = 0xFF52B788;

	static inline var MAX_STRIKES:Int = 3;
	static inline var FISH_CHANCE:Int = 70;

	var player:FlxSprite;
	var items:Array<FallingItem> = [];
	var scoreText:FlxText;
	var strikesText:FlxText;
	var bestText:FlxText;
	var messageText:FlxText;
	var backButton:FlxButton;

	var score:Int = 0;
	var strikes:Int = 0;
	var bestScore:Int = 0;
	var elapsedTime:Float = 0;
	var spawnTimer:Float = 0;
	var isGameOver:Bool = false;
	var isMobile:Bool;

	override public function create():Void
	{
		super.create();

		isMobile = FlxG.onMobile;
		bgColor = COLOR_ABYSS;
		bestScore = Std.int(HighScores.get(GAME_ID));

		player = new FlxSprite(FlxG.width / 2 - 20, FlxG.height - 90);
		player.makeGraphic(40, 24, COLOR_FOAM);
		add(player);

		scoreText = new FlxText(20, 20, 200, "Score: 0");
		scoreText.setFormat(null, isMobile ? 22 : 18, COLOR_FOAM, LEFT);
		add(scoreText);

		strikesText = new FlxText(20, 46, 200, 'Strikes: 0/$MAX_STRIKES');
		strikesText.setFormat(null, isMobile ? 18 : 14, COLOR_DANGER, LEFT);
		add(strikesText);

		bestText = new FlxText(FlxG.width - 140, 20, 120, 'Best: $bestScore');
		bestText.setFormat(null, isMobile ? 18 : 14, COLOR_ACCENT, RIGHT);
		add(bestText);

		messageText = new FlxText(0, FlxG.height / 2 - 40, FlxG.width, "");
		messageText.setFormat(null, isMobile ? 32 : 26, COLOR_FOAM, CENTER);
		add(messageText);

		backButton = new FlxButton(20, FlxG.height - (isMobile ? 70 : 50), "Back", onBackPressed);
		backButton.setSize(isMobile ? 120 : 90, isMobile ? 50 : 32);
		backButton.color = COLOR_ACCENT;
		backButton.label.color = COLOR_ABYSS;
		add(backButton);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (isGameOver)
		{
			handleRestartInput();
			return;
		}

		elapsedTime += elapsed;

		handleMovementInput(elapsed);
		updateSpawning(elapsed);
		updateItems(elapsed);
		checkCatches();
		updateHud();
	}

	function handleMovementInput(elapsed:Float):Void
	{
		var moveSpeed:Float = 360;

		if (FlxG.keys.pressed.LEFT || FlxG.keys.pressed.A)
			player.x -= moveSpeed * elapsed;

		if (FlxG.keys.pressed.RIGHT || FlxG.keys.pressed.D)
			player.x += moveSpeed * elapsed;

		#if FLX_TOUCH
		var touch = FlxG.touches.getFirst();

		if (touch != null)
		{
			var targetX:Float = touch.x - player.width / 2;
			player.x += (targetX - player.x) * Math.min(elapsed * 10, 1);
		}
		#end

		if (player.x < 0)
			player.x = 0;

		if (player.x > FlxG.width - player.width)
			player.x = FlxG.width - player.width;
	}

	function updateSpawning(elapsed:Float):Void
	{
		spawnTimer -= elapsed;

		if (spawnTimer <= 0)
		{
			spawnItem();
			spawnTimer = 0.7 - Math.min(elapsedTime / 90, 0.45);
		}
	}

	function spawnItem():Void
	{
		var isFish:Bool = Std.random(100) < FISH_CHANCE;
		var size:Int = 22 + Std.random(20);
		var sprite = new FlxSprite(Std.random(FlxG.width - size), -size);
		sprite.makeGraphic(size, size, isFish ? COLOR_FISH : COLOR_DANGER);
		add(sprite);
		items.push({sprite: sprite, isFish: isFish});
	}

	function updateItems(elapsed:Float):Void
	{
		var fallSpeed:Float = 140 + elapsedTime * 6;
		var i:Int = items.length - 1;

		while (i >= 0)
		{
			var item:FallingItem = items[i];
			item.sprite.y += fallSpeed * elapsed;

			if (item.sprite.y > FlxG.height)
			{
				remove(item.sprite, true);
				items.splice(i, 1);
			}

			i--;
		}
	}

	function checkCatches():Void
	{
		var i:Int = items.length - 1;

		while (i >= 0)
		{
			var item:FallingItem = items[i];

			if (player.overlaps(item.sprite))
			{
				remove(item.sprite, true);
				items.splice(i, 1);

				if (item.isFish)
					score++;
				else
					registerStrike();
			}

			i--;
		}
	}

	function registerStrike():Void
	{
		strikes++;

		if (strikes >= MAX_STRIKES)
			endGame();
	}

	function updateHud():Void
	{
		scoreText.text = 'Score: $score';
		strikesText.text = 'Strikes: $strikes/$MAX_STRIKES';
	}

	function endGame():Void
	{
		isGameOver = true;

		var isNewBest:Bool = HighScores.submit(GAME_ID, score);

		if (isNewBest)
		{
			bestScore = score;
			bestText.text = 'Best: $bestScore';
		}

		var baseMessage:String = 'Too many strikes! Score: $score';
		messageText.text = (isNewBest ? '$baseMessage\nNew best score!' : baseMessage) + '\nTap or press SPACE to retry';
	}

	function handleRestartInput():Void
	{
		var restartPressed:Bool = FlxG.keys.justPressed.SPACE;

		#if FLX_TOUCH
		if (!restartPressed && FlxG.touches.getFirst() != null && FlxG.touches.getFirst().justPressed)
			restartPressed = true;
		#end

		if (restartPressed)
			FlxG.resetState();
	}

	function onBackPressed():Void
	{
		FlxG.switchState(shark.active.GameState.new);
	}
}
