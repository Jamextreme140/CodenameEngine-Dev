package funkin.menus;

import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import funkin.backend.FunkinText;
import funkin.backend.scripting.events.menu.MenuChangeEvent;
import funkin.backend.scripting.events.menu.storymenu.*;
import funkin.backend.scripting.events.CancellableEvent;
import funkin.savedata.FunkinSave;
import haxe.io.Path;
import haxe.xml.Access;

class StoryMenuState extends MusicBeatState {
	public var characters:Map<String, Access> = [];
	public var weeks:Array<WeekData> = [];

	// yes it supports parameters  - Nex
	public var scoreMessage:String = "WEEK SCORE:{0}";

	public var scoreText:FlxText;
	public var tracklist:FlxText;
	public var weekTitle:FlxText;

	public var curDifficulty:Int = 0;
	public var curWeek:Int = 0;

	public var difficultySprites:Map<String, FlxSprite> = [];
	public var leftArrow:FlxSprite;
	public var rightArrow:FlxSprite;
	public var blackBar:FlxSprite;

	public var weekBG:FlxSprite;
	public var defColor:String = "#F9CF51";
	public var interpColor:FlxInterpolateColor;

	public var lerpScore:Float = 0;
	public var intendedScore:Int = 0;

	public var canSelect:Bool = true;

	public var weekSprites:FlxTypedGroup<MenuItem>;
	public var characterSprites:FlxTypedGroup<FunkinSprite>;

	//public var charFrames:Map<String, FlxFramesCollection> = [];

	public override function create() {
		super.create();
		loadXMLs();
		persistentUpdate = persistentDraw = true;

		// WEEK INFO
		blackBar = new FlxSprite(0, 0).makeSolid(FlxG.width, 56, 0xFFFFFFFF);
		blackBar.color = 0xFF000000;
		blackBar.updateHitbox();

		scoreText = new FunkinText(10, 10, 0, "SCORE: -", 36);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32);

		weekTitle = new FlxText(10, 10, FlxG.width - 20, "", 32);
		weekTitle.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);
		weekTitle.alpha = 0.7;

		weekBG = new FlxSprite(0, 56).makeSolid(FlxG.width, 400, 0xFFFFFFFF);
		weekBG.color = weeks.length > 0 ? weeks[0].bgColor : FlxColor.fromString(defColor);
		weekBG.updateHitbox();

		weekSprites = new FlxTypedGroup<MenuItem>();

		// DUMBASS ARROWS
		var assets = Paths.getFrames('menus/storymenu/assets');
		var directions = ["left", "right"];

		leftArrow = new FlxSprite((FlxG.width + 400) / 2, weekBG.y + weekBG.height + 10 + 10);
		rightArrow = new FlxSprite(FlxG.width - 10, weekBG.y + weekBG.height + 10 + 10);
		for(k=>arrow in [leftArrow, rightArrow]) {
			var dir = directions[k];

			arrow.frames = assets;
			arrow.animation.addByPrefix('idle', 'arrow $dir');
			arrow.animation.addByPrefix('press', 'arrow push $dir', 24, false);
			arrow.animation.play('idle');
			arrow.antialiasing = true;
			add(arrow);
		}
		rightArrow.x -= rightArrow.width;

		tracklist = new FunkinText(16, weekBG.y + weekBG.height + 44, Std.int(((FlxG.width - 400) / 2) - 80), "TRACKS", 32);
		tracklist.alignment = CENTER;
		tracklist.color = 0xFFE55777;

		add(weekSprites);
		for(e in [blackBar, scoreText, weekTitle, weekBG, tracklist]) {
			e.antialiasing = true;
			e.scrollFactor.set();
			add(e);
		}

		add(characterSprites = new FlxTypedGroup<FunkinSprite>());

		for(i=>week in weeks) {
			var spr:MenuItem = new MenuItem(0, (i * 120) + 480, 'menus/storymenu/weeks/${week.sprite}');
			weekSprites.add(spr);

			for(e in week.difficulties) {
				var le = e.toLowerCase();
				if (difficultySprites[le] == null) {
					var diffSprite = new FlxSprite(leftArrow.x + leftArrow.width, leftArrow.y);
					diffSprite.loadAnimatedGraphic(Paths.image('menus/storymenu/difficulties/${le}'));
					diffSprite.setUnstretchedGraphicSize(Std.int(rightArrow.x - leftArrow.x - leftArrow.width), Std.int(leftArrow.height), false, 1);
					diffSprite.antialiasing = true;
					diffSprite.scrollFactor.set();
					add(diffSprite);

					difficultySprites[le] = diffSprite;
				}
			}
		}

		interpColor = new FlxInterpolateColor(weekBG.color);

		// default difficulty should be the middle difficulty in the array
		// to be consistent with base game and whatnot, you know the drill
		curDifficulty = Math.floor(weeks[0].difficulties.length * 0.5);
		// debug stuff lol
		Logs.trace('Middle Difficulty for Week 1 is ${weeks[0].difficulties[curDifficulty]} (ID: $curDifficulty)');

		changeWeek(0, true);

		DiscordUtil.call("onMenuLoaded", ["Story Menu"]);
		CoolUtil.playMenuSong();
	}

	var __lastDifficultyTween:FlxTween;
	public override function update(elapsed:Float) {
		super.update(elapsed);

		lerpScore = lerp(lerpScore, intendedScore, 0.5);
		scoreText.text = scoreMessage.replace("{0}", Std.string(Math.round(lerpScore)));

		if (canSelect) {
			if (leftArrow != null && leftArrow.exists) leftArrow.animation.play(controls.LEFT ? 'press' : 'idle');
			if (rightArrow != null && rightArrow.exists) rightArrow.animation.play(controls.RIGHT ? 'press' : 'idle');

			if (controls.BACK) {
				goBack();
			}

			changeDifficulty((controls.LEFT_P ? -1 : 0) + (controls.RIGHT_P ? 1 : 0));
			changeWeek((controls.UP_P ? -1 : 0) + (controls.DOWN_P ? 1 : 0) - FlxG.mouse.wheel);

			if (controls.ACCEPT)
				selectWeek();
		} else {
			for(e in [leftArrow, rightArrow])
				if (e != null && e.exists)
					e.animation.play('idle');
		}

		interpColor.fpsLerpTo(weeks[curWeek].bgColor, 0.0625);
		weekBG.color = interpColor.color;
	}

	public function goBack() {
		var event = event("onGoBack", new CancellableEvent());
		if (!event.cancelled)
			FlxG.switchState(new MainMenuState());
	}

	public function changeWeek(change:Int, force:Bool = false) {
		if (change == 0 && !force) return;

		var event = event("onChangeWeek", EventManager.get(MenuChangeEvent).recycle(curWeek, FlxMath.wrap(curWeek + change, 0, weeks.length-1), change));
		if (event.cancelled) return;
		curWeek = event.value;

		if (!force) CoolUtil.playMenuSFX();
		for(k=>e in weekSprites.members) {
			e.targetY = k - curWeek;
			e.alpha = k == curWeek ? 1.0 : 0.6;
		}
		tracklist.text = 'TRACKS\n\n${[for(e in weeks[curWeek].songs) if (!e.hide) e.name].join('\n')}';
		weekTitle.text = weeks[curWeek].name.getDefault("");

		if(characterSprites != null) for(i in 0...3) {
			var curChar:FunkinSprite; var newChar:Access = characters[weeks[curWeek].chars[i]];
			if(newChar == null) modifyCharacterAt(i);
			else if((curChar = characterSprites.members[i]) == null || newChar.getAtt("name") != curChar.name) modifyCharacterAt(i, newChar);
		}

		changeDifficulty(0, true);

		MemoryUtil.clearMinor();
	}

	public function modifyCharacterAt(i:Int, ?node:Access):FunkinSprite {
		var old = characterSprites.members[i];
		if(old != null) {
			characterSprites.remove(old);
			old.destroy();
		}

		if(node == null) return null;
		var curChar:FunkinSprite = XMLUtil.createSpriteFromXML(node, "", BEAT);
		curChar.offset.x += curChar.x; curChar.offset.y += curChar.y;
		curChar.setPosition((FlxG.width * 0.25) * (1 + i) - 150, 70);
		if(characterSprites != null) characterSprites.insert(i, curChar);  // Making so many null checks abt this group just in case if mods destroy it  - Nex
		curChar.playAnim("idle", true, DANCE);
		return curChar;
	}

	public override function beatHit(curBeat:Int) {
		super.beatHit(curBeat);
		if(characterSprites != null) characterSprites.forEachAlive(function(spr) spr.beatHit(curBeat));
	}

	var __oldDiffName = null;
	public function changeDifficulty(change:Int, force:Bool = false) {
		if (change == 0 && !force) return;

		var event = event("onChangeDifficulty", EventManager.get(MenuChangeEvent).recycle(curDifficulty, FlxMath.wrap(curDifficulty + change, 0, weeks[curWeek].difficulties.length-1), change));
		if (event.cancelled) return;
		curDifficulty = event.value;

		if (__oldDiffName != (__oldDiffName = weeks[curWeek].difficulties[curDifficulty].toLowerCase())) {
			for(e in difficultySprites) e.visible = false;

			var diffSprite = difficultySprites[__oldDiffName];
			if (diffSprite != null) {
				diffSprite.visible = true;

				if (__lastDifficultyTween != null)
					__lastDifficultyTween.cancel();
				diffSprite.alpha = 0;
				diffSprite.y = leftArrow.y - 15;

				__lastDifficultyTween = FlxTween.tween(diffSprite, {y: leftArrow.y, alpha: 1}, 0.07);
			}
		}

		intendedScore = FunkinSave.getWeekHighscore(weeks[curWeek].id, weeks[curWeek].difficulties[curDifficulty]).score;
	}

	public function loadXMLs() {
		// CoolUtil.coolTextFile(Paths.txt('freeplaySonglist'));
		var weeks:Array<String> = [];

		switch(Flags.WEEKS_LIST_MOD_MODE) {
			case 'prepend':
				getWeeksFromSource(weeks, MODS);
				getWeeksFromSource(weeks, SOURCE);
			case 'append':
				getWeeksFromSource(weeks, SOURCE);
				getWeeksFromSource(weeks, MODS);
			default /*case 'override'*/:
				if (getWeeksFromSource(weeks, MODS))
					getWeeksFromSource(weeks, SOURCE);
		}

		for(k=>weekName in weeks) {
			var week:Access = null;
			try {
				week = new Access(Xml.parse(Assets.getText(Paths.xml('weeks/weeks/$weekName'))).firstElement());
			} catch(e) {
				Logs.trace('Cannot parse week "$weekName.xml": ${Std.string(e)}`', ERROR);
			}

			if (week == null) continue;

			if (!week.has.name) {
				Logs.trace('Story Menu: Week at index ${k} has no name. Skipping...', WARNING);
				continue;
			}
			var weekObj:WeekData = {
				name: week.att.name,
				id: weekName,
				sprite: week.getAtt('sprite').getDefault(weekName),
				chars: [null, null, null],
				songs: [],
				difficulties: ['easy', 'normal', 'hard'],
				bgColor: FlxColor.fromString(week.getAtt("bgColor").getDefault(defColor))
			};

			var diffNodes = week.nodes.difficulty;
			if (diffNodes.length > 0) {
				var diffs:Array<String> = [];
				for(e in diffNodes) {
					if (e.has.name) diffs.push(e.att.name);
				}
				if (diffs.length > 0)
					weekObj.difficulties = diffs;
			}

			if (week.has.chars) {
				for(k=>e in week.att.chars.split(",")) {
					if (e.trim() == "" || e == "none" || e == "null")
						weekObj.chars[k] = null;
					else {
						addCharacter(weekObj.chars[k] = e.trim());
					}
				}
			}
			for(k2=>song in week.nodes.song) {
				if (song == null) continue;
				try {
					var name = song.innerData.trim();
					if (name == "") {
						Logs.trace('Story Menu: Song at index ${k2} in week ${weekObj.name} has no name. Skipping...', WARNING);
						continue;
					}
					weekObj.songs.push({
						name: name,
						hide: song.getAtt('hide').getDefault('false') == "true"
					});
				} catch(e) {
					Logs.trace('Story Menu: Song at index ${k2} in week ${weekObj.name} cannot contain any other XML nodes in its name.', WARNING);
					continue;
				}
			}
			if (weekObj.songs.length <= 0) {
				Logs.trace('Story Menu: Week ${weekObj.name} has no songs. Skipping...', WARNING);
				continue;
			}
			this.weeks.push(weekObj);
		}
	}

	public function addCharacter(charName:String) {
		var char:Access = null;
		try {
			char = new Access(Xml.parse(Assets.getText(Paths.xml('weeks/characters/$charName'))).firstElement());
		} catch(e) {
			Logs.trace('Story Menu: Cannot parse character "$charName.xml": ${Std.string(e)}`', ERROR);
		}

		if(char != null && characters[charName] == null) {
			if(!char.x.exists("name")) char.x.set("name", charName);
			if(!char.x.exists("sprite")) char.x.set("sprite", 'menus/storymenu/characters/${charName}');
			if(!char.x.exists("beatInterval")) char.x.set("beatInterval", "1");
			if(!char.x.exists("updateHitbox")) char.x.set("updateHitbox", "true");
			characters[charName] = char;
		}
	}

	public function getWeeksFromSource(weeks:Array<String>, source:funkin.backend.assets.AssetsLibraryList.AssetSource) {
		var path:String = Paths.txt('freeplaySonglist');
		var weeksFound:Array<String> = [];
		if (Paths.assetsTree.existsSpecific(path, "TEXT", source)) {
			var trim = "";
			weeksFound = CoolUtil.coolTextFile(Paths.txt('weeks/weeks'));
		} else {
			weeksFound = [for(c in Paths.getFolderContent('data/weeks/weeks/', false, source)) if (Path.extension(c).toLowerCase() == "xml") Path.withoutExtension(c)];
		}

		if (weeksFound.length > 0) {
			for(s in weeksFound)
				weeks.push(s);
			return false;
		}
		return true;
	}

	public function selectWeek() {
		var event = event("onWeekSelect", EventManager.get(WeekSelectEvent).recycle(weeks[curWeek], weeks[curWeek].difficulties[curDifficulty], curWeek, curDifficulty));
		if (event.cancelled) return;

		canSelect = false;
		CoolUtil.playMenuSFX(CONFIRM);

		if(characterSprites != null)
			characterSprites.forEachAlive(function(spr) spr.playAnim("confirm", true, LOCK));

		PlayState.loadWeek(event.week, event.difficulty);

		new FlxTimer().start(1, function(tmr:FlxTimer)
		{
			FlxG.switchState(new PlayState());
		});
		weekSprites.members[event.weekID].startFlashing();
	}
}

typedef WeekData = {
	var name:String;  // name SHOULD NOT be used for loading week highscores, its just the name on the right side of the week, remember that next time!!  - Nex
	var id:String;  // id IS instead for saving and loading!!  - Nex
	var sprite:String;
	var chars:Array<String>;
	var songs:Array<WeekSong>;
	var difficulties:Array<String>;
	var bgColor:FlxColor;
}

typedef WeekSong = {
	var name:String;
	var hide:Bool;
}

class MenuItem extends FlxSprite
{
	public var targetY:Float = 0;

	public function new(x:Float, y:Float, path:String)
	{
		super(x, y);
		CoolUtil.loadAnimatedGraphic(this, Paths.image(path, null, true));
		screenCenter(X);
		antialiasing = true;
	}

	private var isFlashing:Bool = false;

	public function startFlashing():Void
	{
		isFlashing = true;
	}

	// if it runs at 60fps, fake framerate will be 6
	// if it runs at 144 fps, fake framerate will be like 14, and will update the graphic every 0.016666 * 3 seconds still???
	// so it runs basically every so many seconds, not dependant on framerate??
	// I'm still learning how math works thanks whoever is reading this lol
	// var fakeFramerate:Int = Math.round((1 / FlxG.elapsed) / 10);

	// hi ninja muffin
	// i have found a more efficient way
	// dw, judging by how week 7 looked you prob know how to do maths
	// goodbye
	var time:Float = 0;

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		time += elapsed;
		y = CoolUtil.fpsLerp(y, (targetY * 120) + 480, 0.17);

		if (isFlashing)
			color = (time % 0.1 > 0.05) ? FlxColor.WHITE : 0xFF33ffff;
	}
}
