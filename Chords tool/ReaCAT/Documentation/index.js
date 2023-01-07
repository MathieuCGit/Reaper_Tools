var docs = [
{path:"module/ReaCAT.html", type:"module", title:"ReaCAT", text:"ReaCAT - Reaper Chord Adding Tool This modules is the main one loaded in Reaper."},
{path:"module/dbg.html", type:"module", title:"dbg", text:"ReaCAT - Debug This module provides tools to debug ReaCAT."},
{path:"module/Analyzer.html", type:"module", title:"Analyzer", text:"ReaCAT - Chord Analyzer. This module provides a bunch of mechanisms to analyze a chord and return a formated string like *G7(&flat;9)*. The main public method is Analyzer:get_chord(pitch_array,take). pitch_array structure should be: For example, here is a CM7. Example"},
{path:"module/Collector.html", type:"module", title:"Collector", text:"ReaCAT - Collector This module aims to get the notes (selected, not selected, all item notes,etc.)in a chord. It only works for the active take passed as an argument."},
{path:"module/SharpOrFlat.html", type:"module", title:"SharpOrFlat", text:"ReaCAT - Sharp or Flat This module aims to detect the key signature we are working with. It also provides methods to manipulate chords according to the key signature detected."},
{path:"module/WriteData.html", type:"module", title:"WriteData", text:"ReaCAT - Write Data This module aims to write chords where you want to get them inputed into reaper."},
{path:"module/Analyzer.html#Analyzer.root", type:"field", title:"Analyzer.root", text:"The root of the chord."},
{path:"module/Analyzer.html#Analyzer.structure", type:"field", title:"Analyzer.structure", text:"The body/structure of the chord."},
{path:"module/Analyzer.html#Analyzer.bass", type:"field", title:"Analyzer.bass", text:"If the chord is in an inverted form, bass is the lowest note. So either the root or the lowest note."},
{path:"module/Analyzer.html#Analyzer.intervalReferenceTable", type:"field", title:"Analyzer.intervalReferenceTable", text:"Interval reference table. This is the main interval reference table. A minor chord will returned as {1,4,8} with 1=\"\", 4=\"m\" and 8=\"\", so only the \"m\" symbol will be returned An exception takes place at the 13th place of the table. As octave are never displayed, we put '5' symbol in this place. 25th place is used as an extra slot for \"dim7\" chord symbol. We also add a 26 slot for the power chords."},
{path:"module/Analyzer.html#Analyzer.root", type:"field", title:"Analyzer.root", text:""},
{path:"module/Collector.html#Collector.chord_start", type:"field", title:"Collector.chord_start", text:"Start of the chord in ppq"},
{path:"module/Collector.html#Collector.chord_end", type:"field", title:"Collector.chord_end", text:"end of the chord in ppq"},
{path:"module/SharpOrFlat.html#SharpOrFlat.enharmonic_table_sharp", type:"field", title:"SharpOrFlat.enharmonic_table_sharp", text:"create enharmonic table for sharp / flat correspondence"},
{path:"module/dbg.html#dbg.new", type:"function", title:"dbg:new", text:"Class constructor"},
{path:"module/dbg.html#dbg.test", type:"function", title:"dbg:test", text:"This is the initial testing method. Used only once to be sure the class is initialized"},
{path:"module/dbg.html#dbg.str", type:"function", title:"dbg:str", text:"Debug function - display messages in reaper console"},
{path:"module/dbg.html#dbg.dumpvar", type:"function", title:"dbg:dumpvar", text:"dumpvar is an implementation of PHP print_r(). dumpvar goes deeper and returns more information than print_r() By Dan Souza: <https://gist.github.com/dansouza/3757165>"},
{path:"module/Analyzer.html#Analyzer.array2Dsort", type:"function", title:"Analyzer.array2Dsort", text:"table.sort() is a very limited and unstable function in lua while dealing with multidimensionnal array so we made another method. more informations can ba found here : http://www.lua.org/manual/5.4/manual.htmlpdf-table.sort"},
{path:"module/Analyzer.html#Analyzer.chordStructureFunc", type:"function", title:"Analyzer.chordStructureFunc", text:"Get usual name from interval numbers, we got the name from the *intervalReferenceTable defined at the beginning of the script. In tonal and occidental modal music, intervals are represented on 2 octaves. So this array is a 24 cases + extra cases (for example 25 = dim) for convenient displaying, I use the 13th case (8ve) to put the 5*."},
{path:"module/Analyzer.html#Analyzer.deepcopy", type:"function", title:"Analyzer.deepcopy", text:"Actually Lua doesn't support table copy as expected in lots of other languages. You *CAN'T* make table2 = table1 and expect table2 to be a new table with table1 data. Here is a snippet from http://lua-users.org/wiki/CopyTable making quite well the job."},
{path:"module/Analyzer.html#Analyzer.detectClusterChords", type:"function", title:"Analyzer.detectClusterChords", text:"If size of Array is upper than 7 we have a non standard chord, means a cluster. <code>retval, retvals_csv=reaper.GetUserInputs()</code>"},
{path:"module/Analyzer.html#Analyzer.find_interval", type:"function", title:"Analyzer.find_interval", text:"This function aims to check if a specific interval exists. If we have a 6 and a 7, 6 becomes a 13 and the chord is no more considered as an inversion. So we need to know if we have M7."},
{path:"module/Analyzer.html#Analyzer.findTheRealRoot", type:"function", title:"Analyzer.findTheRealRoot", text:"This function is the *core analysis one. It aims to get chord intervals in the good order as a human would perform. A 6th is an inverted 3rd. So we have to treat 6th as 3rd. There are 3 exceptions: if there are a 6 AND a 7 or 7M => 6th become a 13th and minor 6th become a b13 dimnished chords always have a major 6th, so be carefull of this case to avoid infinite loop. augmented chords always have a minor 6th, so be carefull of this case to avoid infinite loop."},
{path:"module/Analyzer.html#Analyzer.genericChordParser", type:"function", title:"Analyzer.genericChordParser", text:"This function aims to provide a more conventional displaying for chords. By design it seems better to separate chords recognition from chord displaying because it lets us more possibilities. _Ebmb57_ would be more comprehensive if displayed as _Ebmin7(b5)_ and A major with a 3rd on bass is _AC_ but will be _A/C_ once processed."},
{path:"module/Analyzer.html#Analyzer.getKeySignAtPpq", type:"function", title:"Analyzer.getKeySignAtPpq", text:"Find if we already have a key signature at ppq parameter, +-10 ticks."},
{path:"module/Analyzer.html#Analyzer.manageStandarException", type:"function", title:"Analyzer.manageStandarException", text:"This function aims to manage some exception not as usual mathematical scheme but as a human being would. if we have 4 and 5 semitones from the root note we haven't a minor AND a major chord, we have a major chord with a minor interval (4 semitones) considered as a 9. As each alteration can be understood in 2 octaves we will work on an array of 24 values."},
{path:"module/Analyzer.html#Analyzer.note_to_name", type:"function", title:"Analyzer.note_to_name", text:"convert a note number value into a MIDI note Snippet inspired from the awesome Reaticulate by Jason Tackaberry : https://github.com/jtackaberry/reaticulate/blob/master/app/lib/utils.lua"},
{path:"module/Analyzer.html#Analyzer.removeDuplicates", type:"function", title:"Analyzer.removeDuplicates", text:"This function allow you to remove duplicates entries in an array"},
{path:"module/Analyzer.html#Analyzer.replace_interval", type:"function", title:"Analyzer.replace_interval", text:"This function aims to replace a given interval value by another in a given array"},
{path:"module/Analyzer.html#Analyzer.tablelength", type:"function", title:"Analyzer.tablelength", text:"Get lenght of an indexed table/array."},
{path:"module/Analyzer.html#Analyzer.get_chord", type:"function", title:"Analyzer:get_chord", text:"Perform analyse of pitch_array to determinate chord root, bass and structure. The table pitch_array *MUST get this structure : For example, here is a CM7*. Example"},
{path:"module/Collector.html#Collector.array2Dsort", type:"function", title:"Collector.array2Dsort", text:"table.sort() is a very limited and unstable function in lua while dealing with multidimensionnal array so we made another method. more informations can ba found here : http://www.lua.org/manual/5.4/manual.htmlpdf-table.sort"},
{path:"module/Collector.html#Collector.findFirstNoteStartPpq", type:"function", title:"Collector.findFirstNoteStartPpq", text:"This function aims to provide the start of the first note in either in the active take or in current notes selection."},
{path:"module/Collector.html#Collector.findLastNoteEndPpq", type:"function", title:"Collector.findLastNoteEndPpq", text:"This function aims to provide the end of the last note in either in the active take or in current notes selection."},
{path:"module/Collector.html#Collector.nbrOfSelectedNotes", type:"function", title:"Collector.nbrOfSelectedNotes", text:"Get the number of selected note in a MIDI take."},
{path:"module/Collector.html#Collector.tablelength", type:"function", title:"Collector.tablelength", text:"Get lenght of an indexed table/array."},
{path:"module/Collector.html#Collector.grid_infos", type:"function", title:"Collector:grid_infos", text:"This function aims to provide various informations about grid (division, number of PPQ per grid divisoin unit). Example"},
{path:"module/Collector.html#Collector.get_pitch_array", type:"function", title:"Collector:get_pitch_array", text:"This function aims to create a pitch indexed array of notes in the active take. If no notes are selected, the entire active take notes are put into the array."},
{path:"module/Collector.html#Collector.chord_pos", type:"function", title:"Collector:chord_pos", text:"This method creates a new field in the indexed_pitch_array containing the chord index position start and end. The method take care of human input, if there is less than a 32th note between to notes, they are parts of the same chord."},
{path:"module/Collector.html#Collector.rebuildindex", type:"function", title:"Collector:rebuildindex", text:"Basic function to rebuild a 2D array index as LUA use table and table are not indexed the same way an array is."},
{path:"module/SharpOrFlat.html#SharpOrFlat.ascii_to_utf8", type:"function", title:"SharpOrFlat.ascii_to_utf8", text:"This function let us convert flat and sharp symbols from ASCII to UTF8"},
{path:"module/SharpOrFlat.html#SharpOrFlat.utf8_to_ascii", type:"function", title:"SharpOrFlat.utf8_to_ascii", text:"This function let us convert flat and sharp symbols from UTF8 to ASCII"},
{path:"module/SharpOrFlat.html#SharpOrFlat.get_key_sign_at_ppq", type:"function", title:"SharpOrFlat.get_key_sign_at_ppq", text:"Find if we already have a key signature at ppq parameter, +-10 ticks"},
{path:"module/SharpOrFlat.html#SharpOrFlat.refreshFix", type:"function", title:"SharpOrFlat.refreshFix", text:"Fix for refresh and for writing into all midi items (because does not always work when the cursor is at the start of emasure) from bFooz here : https://forum.cockos.com/showpost.php?p=2445234&postcount=8"},
{path:"module/SharpOrFlat.html#SharpOrFlat.sharp_or_flat", type:"function", title:"SharpOrFlat:sharp_or_flat", text:"This method aims to determine if reaCAT has to use sharp or flat in chords name. It uses item keysignature."},
{path:"module/SharpOrFlat.html#SharpOrFlat.apply_keysign", type:"function", title:"SharpOrFlat:apply_keysign", text:"This method toggle enharmonic value on already existing chords symbols according to key signature detection"},
{path:"module/WriteData.html#WriteData.getTrackByName", type:"function", title:"WriteData.getTrackByName", text:"Find if a track named <code>name</code> exists"},
{path:"module/WriteData.html#WriteData.is_a_chord", type:"function", title:"WriteData.is_a_chord", text:"This function aims to detect if we deal with a chord symbol or with another kind of string"},
{path:"module/WriteData.html#WriteData.del_existing_chord_items", type:"function", title:"WriteData:del_existing_chord_items", text:"Remove existing chord items on \"CHORDS\" track."},
{path:"module/WriteData.html#WriteData.del_existing_chord_symbols", type:"function", title:"WriteData:del_existing_chord_symbols", text:"Remove existing chord symbols."},
{path:"module/WriteData.html#WriteData.notation", type:"function", title:"WriteData:notation", text:"Write chords name in the notation event lane."},
{path:"module/WriteData.html#WriteData.text_event_and_notation", type:"function", title:"WriteData:text_event_and_notation", text:"Write chords name in the textevent lane AND in the notation event lane."},
{path:"module/WriteData.html#WriteData.text_event", type:"function", title:"WriteData:text_event", text:"Write chords name in the textevent lane."},
{path:"module/WriteData.html#WriteData.text_item", type:"function", title:"WriteData:text_item", text:"Create a track named \"CHORDS\", It will contains text items with chords name as text."},
{path:"module/Analyzer.html#private", type:"section", title:"PRIVATE METHODS", text:""},
{path:"module/Analyzer.html#public", type:"section", title:"PUBLIC METHODS", text:""},
{path:"module/Collector.html#private", type:"section", title:"PRIVATE METHODS", text:""},
{path:"module/Collector.html#public", type:"section", title:"PUBLIC METHODS", text:""},
{path:"module/SharpOrFlat.html#private", type:"section", title:"PRIVATE METHODS", text:""},
{path:"module/SharpOrFlat.html#public", type:"section", title:"PUBLIC METHODS", text:""},
{path:"module/WriteData.html#private", type:"section", title:"PRIVATE METHODS", text:""},
{path:"module/WriteData.html#public", type:"section", title:"PUBLIC METHODS", text:""},
];