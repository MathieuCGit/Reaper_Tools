-- @description Auto Pin Floating FX Windows
-- @author Mathieu CONAN   
-- @version 0.1
-- @changelog Initial release
-- @link Github repository https://github.com/MathieuCGit/Reaper_Tools/tree/main
-- @about This script autoamtically toggle ON the pin on each newly opened FX window to keep them foreground
--

--[[
  REAPER - Auto Pin Floating FX Windows
  -------------------------------------

  Description :
    Lorsque le script est ON, toute fenêtre FX flottante
    nouvellement créée est automatiquement "pinnée" / Topmost.

  Dépendance :
    js_ReaScriptAPI

  REAPER :
    7.x

  IMPORTANT :
    JS_Window_AttachTopmostPin() permet d'attacher le Pin,
    mais js_ReaScriptAPI ne fournit actuellement pas de
    fonction permettant de retirer ce Pin.

    Par conséquent :

      ON  = active la surveillance et pinne les nouveaux FX
      OFF = arrête la surveillance

    Les FX déjà pinnés restent pinnés après OFF.

  ------------------------------------------------------------------
  Fonctionnement général
  ------------------------------------------------------------------

    1. Le script est lancé depuis la liste Actions.
    2. Il récupère son propre sectionID / commandID.
    3. Il met son bouton d'action à ON.
    4. Il tourne en arrière-plan avec reaper.defer().
    5. Il parcourt les pistes et leurs FX.
    6. Pour chaque FX flottant, il récupère son HWND.
    7. Si ce HWND n'a jamais été traité :
           JS_Window_AttachTopmostPin(hwnd)
    8. Il mémorise le HWND pour ne pas répéter l'opération.
    9. Lorsque l'action est relancée, elle s'arrête.
]]


--------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------

-- Intervalle entre deux scans, en secondes.
--
-- 0.10 = 10 scans par seconde.
--
-- Ce n'est pas nécessaire d'être extrêmement rapide :
-- un nouveau FX sera détecté au maximum ~100 ms après son ouverture.
local SCAN_INTERVAL = 0.10


--------------------------------------------------------------------
-- VARIABLES D'ÉTAT
--------------------------------------------------------------------

-- Table contenant les HWND que nous avons déjà pinnés.
--
-- Exemple :
--
--     pinned_hwnds[123456] = true
--
-- Cela évite d'appeler continuellement
-- JS_Window_AttachTopmostPin() sur les mêmes fenêtres.
local pinned_hwnds = {}


-- Permet de savoir quand effectuer le prochain scan.
local next_scan = 0


--------------------------------------------------------------------
-- RÉCUPÉRATION DE L'ACTION COURANTE
--------------------------------------------------------------------

-- get_action_context() nous donne notamment :
--
--     section_id
--     command_id
--
-- du script actuellement exécuté.
--
-- C'est indispensable si tu veux utiliser le script comme
-- véritable action REAPER avec un état ON/OFF dans une toolbar.
local _, _, section_id, command_id = reaper.get_action_context()


--------------------------------------------------------------------
-- GESTION DU BOUTON ON/OFF
--------------------------------------------------------------------

local function set_toggle(state)

    -- state doit être :
    --
    --     1 = ON
    --     0 = OFF
    --
    reaper.SetToggleCommandState(
        section_id,
        command_id,
        state
    )

    -- Demande à REAPER de mettre à jour l'affichage
    -- du bouton dans les toolbars.
    reaper.RefreshToolbar2(
        section_id,
        command_id
    )
end


--------------------------------------------------------------------
-- FONCTION DE PIN D'UNE FENÊTRE FX
--------------------------------------------------------------------

local function pin_window(hwnd)

    -- Sécurité :
    -- si le HWND est invalide, on ne fait rien.
    if not hwnd or hwnd == 0 then
        return
    end


    -- Si nous avons déjà traité cette fenêtre,
    -- inutile de refaire l'opération.
    if pinned_hwnds[hwnd] then
        return
    end


    ----------------------------------------------------------------
    -- C'est ici que se produit réellement le "Pin".
    ----------------------------------------------------------------

    reaper.JS_Window_AttachTopmostPin(hwnd)


    ----------------------------------------------------------------
    -- On mémorise le HWND.
    --
    -- Attention :
    -- un HWND Windows peut théoriquement être réutilisé après
    -- destruction d'une fenêtre. Pour notre usage, ce n'est
    -- généralement pas problématique, mais on pourra améliorer
    -- ce point si nécessaire.
    ----------------------------------------------------------------

    pinned_hwnds[hwnd] = true
end


--------------------------------------------------------------------
-- SCAN D'UNE PISTE
--------------------------------------------------------------------

local function scan_track(track)

    -- Nombre de FX présents sur cette piste.
    local fx_count = reaper.TrackFX_GetCount(track)


    -- Les FX sont indexés à partir de 0.
    for fx = 0, fx_count - 1 do

        ------------------------------------------------------------
        -- TrackFX_GetFloatingWindow()
        --
        -- Retourne le HWND de la fenêtre flottante du FX.
        --
        -- Si le FX est docké / intégré dans le FX chain,
        -- la fonction ne nous donne pas de fenêtre flottante
        -- exploitable.
        ------------------------------------------------------------

        local hwnd =
            reaper.TrackFX_GetFloatingWindow(track, fx)


        ------------------------------------------------------------
        -- Si ce FX possède une fenêtre flottante,
        -- on la pinne.
        ------------------------------------------------------------

        if hwnd and hwnd ~= 0 then
            pin_window(hwnd)
        end
    end
end


--------------------------------------------------------------------
-- SCAN DE TOUTES LES PISTES
--------------------------------------------------------------------

local function scan_all_fx()

    ---------------------------------------------------------------
    -- Pistes normales
    ---------------------------------------------------------------

    local track_count = reaper.CountTracks(0)

    for i = 0, track_count - 1 do

        local track = reaper.GetTrack(0, i)

        scan_track(track)
    end


    ---------------------------------------------------------------
    -- Piste Master
    --
    -- CountTracks() ne comprend pas le Master.
    -- On le traite donc séparément.
    ---------------------------------------------------------------

    local master = reaper.GetMasterTrack(0)

    if master then
        scan_track(master)
    end
end


--------------------------------------------------------------------
-- BOUCLE PRINCIPALE
--------------------------------------------------------------------

local function main()

    ---------------------------------------------------------------
    -- Vérification du temps.
    --
    -- On ne veut pas scanner toutes les pistes à chaque appel
    -- de defer(), car cela pourrait devenir inutilement coûteux.
    ---------------------------------------------------------------

    local now = reaper.time_precise()

    if now >= next_scan then

        next_scan = now + SCAN_INTERVAL

        scan_all_fx()
    end


    ---------------------------------------------------------------
    -- Replanifie l'exécution de cette fonction.
    --
    -- C'est ce qui transforme le script en script "background".
    ---------------------------------------------------------------

    reaper.defer(main)
end


--------------------------------------------------------------------
-- NETTOYAGE À L'ARRÊT DU SCRIPT
--------------------------------------------------------------------

local function exit()

    ---------------------------------------------------------------
    -- Lorsque le script est arrêté, on remet son bouton à OFF.
    --
    -- Cela est important notamment si le script est placé dans
    -- une toolbar.
    ---------------------------------------------------------------

    set_toggle(0)


    ---------------------------------------------------------------
    -- On vide notre table.
    --
    -- Cela ne retire PAS les Pins des fenêtres :
    -- js_ReaScriptAPI ne fournit pas de fonction pour les détacher.
    --
    -- Cela sert simplement à nettoyer notre état Lua.
    ---------------------------------------------------------------

    pinned_hwnds = {}
end


--------------------------------------------------------------------
-- INITIALISATION
--------------------------------------------------------------------

-- Le script vient d'être lancé :
-- on indique immédiatement à REAPER que l'action est ON.
set_toggle(1)


-- Enregistre notre fonction de nettoyage.
reaper.atexit(exit)


-- Lance la boucle.
main()