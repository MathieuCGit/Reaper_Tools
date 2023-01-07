ReaCAT - Reaper Chords Adding Tool
==================================

Basic usage
-----------

ReaCAT aims to provide a tool to perform and use chords in Reaper. It consists mainly in analysis chords in different ways and adding them in different places (text event, notation chords, item text note...). it's a MIDI tool, you can't find chords from audio with it.

By default, once installed with ReaPack, it appears in the Reaper's action list. 

Here is the reapack link to paste into Extension > Reapack > import repositories.. : https://raw.githubusercontent.com/MathieuCGit/Reaper_Tools/main/index.xml

:warning:To get it to work with good enharmonic related to tonality, you **MUST** right click on key at staff start and verify that **"Key signature changes affect all tracks"** is **UNCHECK**. If each item doesn't have its own key signature, the script will return a default key signature value.

### Example 1
![generate chord track](https://github.com/MathieuCGit/Reaper_Tools/blob/main/Chords%20tool/ReaCAT/Documentation/img/ReaCAT_quick_anim.gif)

### Example 2
![MIDI editor and notation view coherent](https://github.com/MathieuCGit/Reaper_Tools/blob/main/Chords%20tool/ReaCAT/Documentation/img/ReaCAT_quick_anim02.gif)


---

Devs Corner
-----------

ReaCAT is also a set of classes you can use into your own scripts.

:information_source: **You will find a detailled documentation in the Documentation folder. If you want to dig deeper into this, please clone this repository and load Documentation/index.html in a browser.**

### Architecture

ReaCAT is coded in a kind of Oriented Object vision. It is divided in lua files. Each file can be understood as a class. 
The main lua file is **ReaCAT.lua**, it contains basic calls to the classes and can be used easily by end users.

So first of all we use the **Collector** to get context informations, then we use the **Analyzer** which result in a formated string chord like **G7(&flat;9)**, we use the **SharpOrFlat** to set the sharp and flat symbols regarding the key signature context and finally we use the **WriteData** class to put chord symbols where we want.

### Analyzer

This class provides a bunch of mechanisms to analyze a chord and return a formated string like **G7(&flat;9)**.

Please take in consideration that chord recognition performed by this class is not a classic array base method. indeed, it uses a more human approach. 

It aims to get chord intervals in the good order the same way a human would perform. 

A 6th is an inverted 3rd. So we have to treat 6th as 3rd. Thinking like this, we can face 2 problems:
- *dimnished chords only have a major 6th, so be carefull of this case to avoid infinite loop.*
- *augmented chords only have a minor 6th, so be carefull of this case to avoid infinite loop.*	

The main public method is `Analyzer:get_chord(pitch_array,take)`.

`pitch_array` structure should be:
 ```
  pitch_array={
   [idx]=int,
   [idx]=int,
   [idx]=int,
   [idx]=int,
   [idx]=etc...}
```

For example, here is a CM7.
```
   pitch_array={
	[1]=60, --C
	[2]=64, --E
	[3]=67, --G
	[4]=71  --B
	}
```

Tipicaly, you first need to add the class to your code.
```
	-- find the program path
	local sep = package.config:sub(1, 1) -- separators depend on operating system, windows = \, linux and osX = /
	local script = debug.getinfo(1, 'S').source:sub(2) --absolute path + filename of current running script
	local pattern = "(.*" .. sep .. ")" -- every char before sep
	local basedir = script:match(pattern) -- rootpath of current running script
	local filename_without_ext = script:match("(.+)%.[^%.]+$")
	package.path =string.format(basedir.."?.lua")

	--load desire modules
	require 'Analyzer'
	--this means your file "Analyzer.lua" is in the same folder than your current script.
```

If you want the classes to be in a subfolder like, for example, `lib`, you have to call you classes like this:
```
require 'lib.Analyzer'
```

If you got the `pitch_array` you just have to call the class.
`take` is a classic Reaper take you can get by using function such as ` reaper.GetActiveTake( item )` or ` reaper.GetMediaItemTake( item, track )` depending of the context (main windows, MIDI Editor,etc.)
```
	new_chord=Analyzer:new()
	result=new_chord:get_chord(pitch_array, take)
```

:arrow_forward: `result` will be a chord symbol like **G7(&flat;9)**.

### Collector

This module aims to get the notes (selected, not selected, all item notes,etc.)in a chord. It only works for the active take passed as an argument.

### SharpOrFlat

This module aims to detect the key signature we are working with. It also provides methods to manipulate chords according to the key signature detected.

Very easy to use, argument are a chord symbol and a reaper take. The class get key signature from the take and change the chord symbol accordingly.

```
new_chord=SharpOrFlat:apply_keysign(chord_symbol,take)
```

:warning: You <u>**MUST**</u> right click on key at staff start and verify that "*Key signature changes affect all tracks*" is **UNCHECK**. If each item doesn't have its own key signature, the script will return a default key signature value.

### WriteData 
 
This module aims to write chords symbols where you want to get them inputed into reaper. Here is a list of actually supported method :

- `WriteData:notation(take,chord,startpos)` -> write chords in the notation view
- `WriteData:text_event_and_notation(take,chord,startpos)` -> write chords in the notation view and as MIDI text event
- `WriteData:text_event(take,chord,startpos)` -> write chords as MIDI text event
- `WriteData:text_item(take,chord,startpos,endpos)` -> create a CHORDS track at the track list's top and create text item for chords

### Requirements
- Reaper 6.30 or newer
- SWS Extension 2.13.1 <https://www.sws-extension.org/download/pre-release/>
- Python 3.9.6 (for luadox auto generated documentation)

### Documentation
Documentation is mainly auto-generated by [luadox](https://github.com/jtackaberry/luadox) so, please, if you want to contribute, have a look at luadox documentation.