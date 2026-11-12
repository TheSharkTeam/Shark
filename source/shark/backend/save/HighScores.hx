package shark.backend.save;

class HighScores
{
	static inline var KEY_PREFIX:String = "highscore_";

	public static function get(gameId:String):Float
	{
		return ClientPrefs.getFloat(KEY_PREFIX + gameId, 0);
	}

	public static function submit(gameId:String, score:Float):Bool
	{
		if (score <= get(gameId))
			return false;

		ClientPrefs.setFloat(KEY_PREFIX + gameId, score);
		return true;
	}
}
