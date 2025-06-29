package funkin.backend.system;

#if MOD_SUPPORT
import sys.FileSystem;
#end
import flixel.FlxState;
import funkin.backend.assets.ModsFolder;
import funkin.backend.chart.EventsData;
import funkin.menus.BetaWarningState;
import funkin.menus.TitleState;
import funkin.backend.system.framerate.Framerate;

/**
 * Simple state used for loading the game
 */
class MainState extends FlxState {
	public static var initiated:Bool = false;
	public static var betaWarningShown:Bool = false;
	public override function create() {
		super.create();
		if (!initiated) {
			Main.loadGameSettings();
		}

		initiated = true;

		#if sys
		CoolUtil.deleteFolder('./.temp/'); // delete temp folder
		#end
		Options.save();

		FlxG.bitmap.reset();
		FlxG.sound.destroy(true);

		Paths.assetsTree.reset();

		#if MOD_SUPPORT
		var _lowPriorityAddons:Array<String> = [];
		var _highPriorityAddons:Array<String> = [];
		var _noPriorityAddons:Array<String> = [];
		if (FileSystem.exists(ModsFolder.addonsPath) && FileSystem.isDirectory(ModsFolder.addonsPath)) {
			for(i=>addon in [for(dir in FileSystem.readDirectory(ModsFolder.addonsPath)) if (FileSystem.isDirectory('${ModsFolder.addonsPath}$dir')) dir]) {
				if (addon.startsWith("[LOW]")) _lowPriorityAddons.insert(0, addon);
				else if (addon.startsWith("[HIGH]")) _highPriorityAddons.insert(0, addon);
				else _noPriorityAddons.insert(0, addon);
			}
			for (addon in _lowPriorityAddons)
				Paths.assetsTree.addLibrary(ModsFolder.loadModLib('${ModsFolder.addonsPath}$addon', StringTools.ltrim(addon.substr("[LOW]".length))));
		}
		if (ModsFolder.currentModFolder != null)
			Paths.assetsTree.addLibrary(ModsFolder.loadModLib('${ModsFolder.modsPath}${ModsFolder.currentModFolder}', ModsFolder.currentModFolder));

		if (FileSystem.exists(ModsFolder.addonsPath) && FileSystem.isDirectory(ModsFolder.addonsPath)){
			for (addon in _noPriorityAddons) Paths.assetsTree.addLibrary(ModsFolder.loadModLib('${ModsFolder.addonsPath}$addon', addon));
			for (addon in _highPriorityAddons) Paths.assetsTree.addLibrary(ModsFolder.loadModLib('${ModsFolder.addonsPath}$addon', StringTools.ltrim(addon.substr("[HIGH]".length))));
		}
		#end

		Flags.load();
		ModsFolder.onModSwitch.dispatch(ModsFolder.currentModFolder); // Loads global.hx
		MusicBeatTransition.script = Flags.DEFAULT_TRANSITION_SCRIPT;
		WindowUtils.resetTitle();
		Main.refreshAssets();
		DiscordUtil.init();
		EventsData.reloadEvents();
		TitleState.initialized = false;

		if(Framerate.isLoaded)
			Framerate.instance.reload();

		if (Flags.DISABLE_BETA_WARNING_SCREEN || betaWarningShown)
			FlxG.switchState(new TitleState());
		else
			FlxG.switchState(new BetaWarningState());
		betaWarningShown = true;

		#if sys
		CoolUtil.safeAddAttributes('./.temp/', NativeAPI.FileAttribute.HIDDEN);
		#end
	}
}