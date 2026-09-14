-- @description Disable pin for every opened FX windows
-- @version 0.1
-- @author Mathieu CONAN   
-- @changelog Initial release
-- @link Github repository https://github.com/MathieuCGit/Reaper_Tools/tree/main
-- @about This script toggle OFF the pin for each opened FX window to keep them foreground
--

--[[
========================================================================
 REAPER - FX : Unpin All
========================================================================

 DESCRIPTION
 -----------------------------------------------------------------------
 Cette action recherche toutes les fenêtres FX flottantes actuellement
 ouvertes et retire leur statut "Always on top".

 Elle utilise :

     JS_Window_SetZOrder(hwnd, "NOTOPMOST", nil)

 "NOTOPMOST" demande à Windows de retirer la fenêtre de la liste des
 fenêtres toujours au-dessus.

 IMPORTANT
 -----------------------------------------------------------------------
 Cette action ne ferme aucun FX.

 Elle ne modifie pas :
     - les paramètres des FX
     - les presets
     - le FX Chain
     - le dockage
     - la position de la fenêtre

 Elle ne fait que modifier le Z-order des fenêtres FX flottantes.

========================================================================
]]


-----------------------------------------------------------------------
-- Vérification de js_ReaScriptAPI
-----------------------------------------------------------------------

if not reaper.JS_Window_SetZOrder then
    reaper.ShowMessageBox(
        "js_ReaScriptAPI n'est pas installé ou n'est pas chargé.",
        "FX - Unpin All",
        0
    )
    return
end


-----------------------------------------------------------------------
-- UNPIN D'UNE FENÊTRE
-----------------------------------------------------------------------

local function unpin_window(hwnd)

    -- Sécurité.
    if not hwnd or hwnd == 0 then
        return
    end


    -------------------------------------------------------------------
    -- NOTOPMOST est l'opération inverse de TOPMOST.
    --
    -- La fenêtre redevient donc une fenêtre normale dans le Z-order
    -- Windows.
    -------------------------------------------------------------------

    reaper.JS_Window_SetZOrder(
        hwnd,
        "NOTOPMOST",
        nil
    )
end


-----------------------------------------------------------------------
-- SCAN D'UNE PISTE
-----------------------------------------------------------------------

local function unpin_track_fx(track)

    -- Nombre de FX de la piste.
    local fx_count = reaper.TrackFX_GetCount(track)


    -- Parcours des FX.
    for fx = 0, fx_count - 1 do

        ---------------------------------------------------------------
        -- Récupération de la fenêtre flottante.
        ---------------------------------------------------------------

        local hwnd =
            reaper.TrackFX_GetFloatingWindow(track, fx)


        ---------------------------------------------------------------
        -- Si une fenêtre flottante existe :
        -- retrait du TOPMOST.
        ---------------------------------------------------------------

        if hwnd and hwnd ~= 0 then
            unpin_window(hwnd)
        end
    end
end


-----------------------------------------------------------------------
-- PARCOURS DES PISTES
-----------------------------------------------------------------------

local track_count = reaper.CountTracks(0)

for i = 0, track_count - 1 do

    local track = reaper.GetTrack(0, i)

    unpin_track_fx(track)
end


-----------------------------------------------------------------------
-- MASTER
-----------------------------------------------------------------------

local master = reaper.GetMasterTrack(0)

if master then
    unpin_track_fx(master)
end