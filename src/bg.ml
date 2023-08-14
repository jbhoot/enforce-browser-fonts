open Js_api
open Rxjs
open Common
open Ffext

(*
. (initial_state, state_change) -> (icon, tooltip, about_config)
. browserAction.clicked -> (state_change) -> (save website to excluded or included)
*)

(*
   . first time config loaded
   . config changed
   . tab activated (switched to another tab)
   . tab updated (another page loaded in a tab)
   . browserAction
*)

(*
   let _ = Browser.Browser_action.On_clicked.
*)
let s_initial_config =
  Data.make_default ()
  |. Data.serialise
  |. Storage.Local.get
  |. Stream.from_promise
  |. Stream.pipe1 (Op.map (fun v _i -> Data.deserialise v))

let s_initial_preferred_font =
  s_initial_config |. Stream.pipe1 (Op.map (fun v _i -> v.Data.default_fonts))

let s_initial_excluded_from_browser_fonts =
  s_initial_config
  |. Stream.pipe1 (Op.map (fun v _i -> v.Data.browser_fonts_exclude))

let s_initial_excluded_from_document_fonts =
  s_initial_config
  |. Stream.pipe1 (Op.map (fun v _i -> v.Data.document_fonts_exclude))

let s_preferences_changed =
  Stream.from_event_pattern2
    (fun handler -> Storage.On_changed.add_listener handler)
    (fun handler _signal -> Storage.On_changed.remove_listener handler)
    (fun t_change _area_name -> t_change)

let s_preferred_font_changed =
  s_preferences_changed
  |. Stream.pipe4
       (Op.filter (fun v _i ->
            Option.is_some v.Common.Storage_types.defaultFonts))
       (Op.map (fun v _i -> v.Common.Storage_types.defaultFonts |. Option.get))
       (Op.filter (fun v _i -> Option.is_some v.Common.Storage_types.newValue))
       (Op.map (fun v _i ->
            v.Common.Storage_types.newValue
            |. Option.get
            |. Data.Font_type.from_string))

let s_excluded_from_browser_fonts_changed =
  s_preferences_changed
  |. Stream.pipe5
       (Op.filter (fun v _i ->
            Option.is_some v.Common.Storage_types.browserFonts))
       (Op.map (fun v _i -> v.Common.Storage_types.browserFonts |. Option.get))
       (Op.filter (fun v _i -> Option.is_some v.Common.Storage_types.newValue))
       (Op.map (fun v _i -> v.Common.Storage_types.newValue |. Option.get))
       (Op.map (fun v _i -> Set.from_array v.Common.Storage_types.exclude))

let s_excluded_from_document_fonts_changed =
  s_preferences_changed
  |. Stream.pipe5
       (Op.filter (fun v _i ->
            Option.is_some v.Common.Storage_types.documentFonts))
       (Op.map (fun v _i -> v.Common.Storage_types.documentFonts |. Option.get))
       (Op.filter (fun v _i -> Option.is_some v.Common.Storage_types.newValue))
       (Op.map (fun v _i -> v.Common.Storage_types.newValue |. Option.get))
       (Op.map (fun v _i -> Set.from_array v.Common.Storage_types.exclude))

let filter_browser_fonts =
  Op.filter (fun v _i ->
      match v with
      | Data.Font_type.Browser_fonts -> true
      | Document_fonts -> false)

let filter_document_fonts =
  Op.filter (fun v _i ->
      match v with
      | Data.Font_type.Browser_fonts -> false
      | Document_fonts -> true)

let s_browser_fonts_preferred =
  Op.merge2 s_initial_preferred_font s_preferred_font_changed
  |. Stream.pipe1 filter_browser_fonts

let s_document_fonts_preferred =
  Op.merge2 s_initial_preferred_font s_preferred_font_changed
  |. Stream.pipe1 filter_document_fonts

let c_excluded_from_browser_fonts =
  Op.merge2 s_initial_excluded_from_browser_fonts
    s_excluded_from_browser_fonts_changed
  |. Op.hold (Set.empty ())

let c_excluded_from_document_fonts =
  Op.merge2 s_initial_excluded_from_document_fonts
    s_excluded_from_document_fonts_changed
  |. Op.hold (Set.empty ())

let s_until_browser_fonts_preferred =
  (* NOTE: Do not use a merged stream of (s_initial_default_font, s_default_font_pref_updated) as a stopper stream. The value coming through s_initial_default_font messes things up when config is updated in add-on settings. *)
  s_preferred_font_changed |. Stream.pipe1 filter_browser_fonts

let s_until_document_fonts_preferred =
  s_preferred_font_changed |. Stream.pipe1 filter_document_fonts

let s_browser_action_activated =
  Stream.from_event_pattern2
    (fun handler -> Browser.Browser_action.On_clicked.add_listener handler)
    (fun handler _signal ->
      Browser.Browser_action.On_clicked.remove_listener handler)
    (fun tab _on_click_data -> tab)

let s_browser_action_to_apply_browser_fonts_activated =
  s_browser_fonts_preferred
  |. Stream.pipe1
       (Op.merge_map (fun _v _i ->
            s_browser_action_activated
            |. Stream.pipe1 (Op.take_until s_until_document_fonts_preferred)))

let s_browser_action_to_apply_document_fonts_activated =
  s_document_fonts_preferred
  |. Stream.pipe1
       (Op.merge_map (fun _v _i ->
            s_browser_action_activated
            |. Stream.pipe1 (Op.take_until s_until_browser_fonts_preferred)))

let _ =
  s_browser_action_to_apply_browser_fonts_activated
  |. Stream.subscribe (fun tab ->
         let curr_set = Cell.get_value c_excluded_from_browser_fonts in
         Js.Console.log2 "before c_excluded_from_browser_fonts"
           (curr_set |. Set.to_array);
         let new_set =
           match Set.has curr_set tab.url with
           | true ->
             Set.delete curr_set tab.url |. ignore;
             curr_set
           | false -> Set.add curr_set tab.url
         in
         let () =
           match Set.has new_set tab.url with
           | true ->
             Browser.Browser_action.set_icon { path = "./src/icons/off.svg" }
             |. ignore;
             Browser.Browser_action.set_title { title = "Using document fonts" }
             |. ignore;
             Browser.Browser_settings.Use_document_fonts.set { value = true }
             |. ignore
           | false ->
             Browser.Browser_action.set_icon { path = "./src/icons/on.svg" }
             |. ignore;
             Browser.Browser_action.set_title { title = "Using browser fonts" }
             |. ignore;
             Browser.Browser_settings.Use_document_fonts.set { value = false }
             |. ignore
         in

         Js.Console.log2 "Setting"
           (Common.Storage_types.t_partial
              ~browserFonts:{ exclude = Set.to_array new_set }
              ());
         Storage.Local.set
           (Common.Storage_types.t_partial
              ~browserFonts:{ exclude = Set.to_array new_set }
              ())
         |. ignore)

let _ =
  s_browser_action_to_apply_document_fonts_activated
  |. Stream.subscribe (fun tab ->
         let curr_set = Cell.get_value c_excluded_from_document_fonts in
         Js.Console.log2 "before c_excluded_from_document_fonts"
           (curr_set |. Set.to_array);
         let new_set =
           match Set.has curr_set tab.url with
           | true ->
             Set.delete curr_set tab.url |. ignore;
             curr_set
           | false -> Set.add curr_set tab.url
         in
         let () =
           match Set.has new_set tab.url with
           | true ->
             Browser.Browser_action.set_icon { path = "./src/icons/on.svg" }
             |. ignore;
             Browser.Browser_action.set_title { title = "Using browser fonts" }
             |. ignore;
             Browser.Browser_settings.Use_document_fonts.set { value = false }
             |. ignore
           | false ->
             Browser.Browser_action.set_icon { path = "./src/icons/off.svg" }
             |. ignore;
             Browser.Browser_action.set_title { title = "Using website fonts" }
             |. ignore;
             Browser.Browser_settings.Use_document_fonts.set { value = true }
             |. ignore
         in

         Js.Console.log2 "Setting"
           (Common.Storage_types.t_partial
              ~documentFonts:{ exclude = Set.to_array new_set }
              ());
         Storage.Local.set
           (Common.Storage_types.t_partial
              ~documentFonts:{ exclude = Set.to_array new_set }
              ())
         |. ignore)
