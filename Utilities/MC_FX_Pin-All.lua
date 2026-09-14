-- @description Enable pin for every opened FX windows
-- @author Mathieu CONAN   
-- @version 0.1
-- @changelog Initial release
-- @link Github repository https://github.com/MathieuCGit/Reaper_Tools/tree/main
-- @about This script toggle ON the pin on each opened FX window to keep them foreground
--


--[[
========================================================================
 REAPER - FX : Pin All
========================================================================

 DESCRIPTION
 -----------------------------------------------------------------------
 Cette action recherche toutes les fenêtres FX flottantes actuellement
 ouvertes dans le projet et les rend "Always on top".

 Elle utilise deux fonctions de js_ReaScriptAPI :

     JS_Window_AttachTopmostPin(hwnd)

     JS_Window_SetZOrder(hwnd, "TOPMOST", nil)

 La première attache à la fenêtre le mécanisme de "Topmost Pin" de
 REAPER.

 La seconde force explicitement la fenêtre dans le Z-order Windows
 "TOPMOST".

 L'utilisation des deux permet d'être assez robuste selon le type
 de fenêtre FX et la manière dont REAPER l'a créée.

 IMPORTANT
 -----------------------------------------------------------------------
 Le script ne touche PAS aux FX dockés dans le FX Chain.

 Il ne traite que les FX pour lesquels :

     TrackFX_GetFloatingWindow()

 retourne un HWND valide.

 Il traite également les FX du Master.

========================================================================
]]

-----------------------------------------------------------------------
-- Vérification de js_ReaScriptAPI
-----------------------------------------------------------------------

-- JS_Window_SetZOrder et JS_Window_AttachTopmostPin appartiennent
-- à js_ReaScriptAPI.
--
-- Si l'extension n'est pas installée, les fonctions n'existeront pas.

if not reaper.JS_Window_SetZOrder then
    reaper.ShowMessageBox(
        "js_ReaScriptAPI n'est pas installé ou n'est pas chargé.",
        "FX - Pin All",
        0
    )
    return
end


-----------------------------------------------------------------------
-- PIN D'UNE FENÊTRE
-----------------------------------------------------------------------

local function pin_window(hwnd)

    -- Sécurité : un HWND nul n'est pas exploitable.
    if not hwnd or hwnd == 0 then
        return
    end


    -------------------------------------------------------------------
    -- On attache le bouton / mécanisme "Topmost Pin" de REAPER.
    --
    -- C'est la fonction spécifique de js_ReaScriptAPI qui permet
    -- d'attacher le comportement de l'épingle à une fenêtre.
    -------------------------------------------------------------------

    if reaper.JS_Window_AttachTopmostPin then
        reaper.JS_Window_AttachTopmostPin(hwnd)
    end


    -------------------------------------------------------------------
    -- On force également le HWND dans le Z-order TOPMOST de Windows.
    --
    -- "TOPMOST" signifie que la fenêtre reste au-dessus des fenêtres
    -- normales.
    --
    -- Le troisième argument est nil car nous ne voulons pas insérer
    -- la fenêtre relativement à un HWND particulier.
    -------------------------------------------------------------------

    reaper.JS_Window_SetZOrder(
        hwnd,
        "TOPMOST",
        nil
    )
end


-----------------------------------------------------------------------
-- SCAN D'UNE PISTE
-----------------------------------------------------------------------

local function pin_track_fx(track)

    -- Nombre de FX sur cette piste.
    local fx_count = reaper.TrackFX_GetCount(track)


    -- Parcours de tous les FX.
    --
    -- REAPER utilise une indexation à partir de 0.
    for fx = 0, fx_count - 1 do

        ---------------------------------------------------------------
        -- Récupération du HWND de la fenêtre flottante du FX.
        --
        -- Si le FX est docké / intégré dans le FX Chain, la fonction
        -- ne renvoie pas une fenêtre flottante utilisable.
        ---------------------------------------------------------------

        local hwnd =
            reaper.TrackFX_GetFloatingWindow(track, fx)


        ---------------------------------------------------------------
        -- Si le FX possède bien une fenêtre flottante :
        -- on la pince.
        ---------------------------------------------------------------

        if hwnd and hwnd ~= 0 then
            pin_window(hwnd)
        end
    end
end


-----------------------------------------------------------------------
-- PARCOURS DU PROJET
-----------------------------------------------------------------------

-- Nombre de pistes normales.
local track_count = reaper.CountTracks(0)


-- Parcours des pistes normales.
for i = 0, track_count - 1 do

    local track = reaper.GetTrack(0, i)

    pin_track_fx(track)
end


-----------------------------------------------------------------------
-- MASTER
-----------------------------------------------------------------------

-- CountTracks() ne comprend pas le Master.
-- On le traite donc séparément.

local master = reaper.GetMasterTrack(0)

if master then
    pin_track_fx(master)
end