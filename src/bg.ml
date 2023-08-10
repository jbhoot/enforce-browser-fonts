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

let defaults = Data.make_default ()

let s_initial_config =
  defaults
  |. Data.serialise
  |. Storage.Local.get
  |. Stream.from_promise
  |. Stream.pipe1 (Op.map (fun v _i -> Data.deserialise v))

let s_initial_default_font =
  s_initial_config |. Stream.pipe1 (Op.map (fun v _i -> v.Data.default_fonts))

let s_pref_updated =
  Stream.from_event_pattern2
    (fun handler -> Storage.On_changed.add_listener handler)
    (fun handler _signal -> Storage.On_changed.remove_listener handler)
    (fun t_change _area_name -> t_change)

let s_default_font_pref_updated =
  s_pref_updated
  |. Stream.pipe2
       (Op.filter (fun v _i ->
            Option.is_some v.Common.Storage_types.defaultFonts.newValue))
       (Op.map (fun v _i ->
            v.Common.Storage_types.defaultFonts.newValue
            |. Option.get
            |. Data.Font_type.from_string))

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

let s_enforce_browser_fonts =
  Op.merge2 s_initial_default_font s_default_font_pref_updated
  |. Stream.pipe1 filter_browser_fonts

let s_enforce_document_fonts =
  Op.merge2 s_initial_default_font s_default_font_pref_updated
  |. Stream.pipe1 filter_document_fonts

let s_stopper_enforce_browser_fonts =
  (* NOTE: Do not use a merged stream of (s_initial_default_font, s_default_font_pref_updated) as a stopper stream. The value coming through s_initial_default_font messes things up when config is updated in add-on settings. *)
  s_default_font_pref_updated |. Stream.pipe1 filter_browser_fonts

let s_stopper_enforce_document_fonts =
  s_default_font_pref_updated |. Stream.pipe1 filter_document_fonts

let s_browser_action_clicked =
  Stream.from_event_pattern2
    (fun handler -> Browser.Browser_action.On_clicked.add_listener handler)
    (fun handler _signal ->
      Browser.Browser_action.On_clicked.remove_listener handler)
    (fun tab _on_click_data -> tab)

let s_ebf =
  s_enforce_browser_fonts
  |. Stream.pipe1
       (Op.merge_map (fun _v _i ->
            s_browser_action_clicked
            |. Stream.pipe1 (Op.take_until s_stopper_enforce_document_fonts)))

let s_edf =
  s_enforce_document_fonts
  |. Stream.pipe1
       (Op.merge_map (fun _v _i ->
            s_browser_action_clicked
            |. Stream.pipe1 (Op.take_until s_stopper_enforce_browser_fonts)))

let _ =
  s_ebf
  |. Stream.subscribe (fun v ->
         Js.Console.log2 "Subscribed to enforce for " v.url)

let _ =
  s_edf
  |. Stream.subscribe (fun v ->
         Js.Console.log2 "Subscribed to don't enforce for " v.url)
