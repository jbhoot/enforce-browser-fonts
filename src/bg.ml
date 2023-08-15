open Js_api
open Rxjs
open Common
open Ffext

(*
- strip to domain name only
- tabUpdated: use tab.isLoading flag to filter state?
*)

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
let default_data = Data.make_default ()

let s_initial_config =
  default_data
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

let c_preferred_fonts =
  Op.merge2 s_initial_preferred_font s_preferred_font_changed
  |. Op.hold default_data.default_fonts

let c_excluded_from_browser_fonts =
  Op.merge2 s_initial_excluded_from_browser_fonts
    s_excluded_from_browser_fonts_changed
  |. Op.hold (Set.empty ())

let c_excluded_from_document_fonts =
  Op.merge2 s_initial_excluded_from_document_fonts
    s_excluded_from_document_fonts_changed
  |. Op.hold (Set.empty ())

let s_browser_action_activated =
  Stream.from_event_pattern2
    (fun handler -> Browser.Browser_action.On_clicked.add_listener handler)
    (fun handler _signal ->
      Browser.Browser_action.On_clicked.remove_listener handler)
    (fun tab _on_click_data -> tab)

let update_excluded_domains curr_set (tab : Browser.tab) =
  match Set.has curr_set tab.url with
  | true ->
    Set.delete curr_set tab.url |. ignore;
    curr_set
  | false -> Set.add curr_set tab.url

let store_excluded_domains set font_type =
  match font_type with
  | Data.Font_type.Browser_fonts ->
    Storage.Local.set
      (Common.Storage_types.t_partial
         ~browserFonts:{ exclude = Set.to_array set }
         ())
    |. ignore
  | Data.Font_type.Document_fonts ->
    Storage.Local.set
      (Common.Storage_types.t_partial
         ~documentFonts:{ exclude = Set.to_array set }
         ())
    |. ignore

let enforce font_type =
  match font_type with
  | Data.Font_type.Browser_fonts ->
    Browser.Browser_action.set_icon { path = "./src/icons/on.svg" } |. ignore;
    Browser.Browser_action.set_title { title = "Using browser fonts" } |. ignore;
    Browser.Browser_settings.Use_document_fonts.set { value = false } |. ignore
  | Document_fonts ->
    Browser.Browser_action.set_icon { path = "./src/icons/off.svg" } |. ignore;
    Browser.Browser_action.set_title { title = "Using document fonts" }
    |. ignore;
    Browser.Browser_settings.Use_document_fonts.set { value = true } |. ignore

let s_tab_activated =
  Stream.from_event_pattern
    (fun handler -> Browser.Tabs.On_activated.add_listener handler)
    (fun handler _signal -> Browser.Tabs.On_activated.remove_listener handler)
    (fun active_info -> active_info)

let s_tab_updated =
  Stream.from_event_pattern3
    (fun handler -> Browser.Tabs.On_updated.add_listener handler)
    (fun handler _signal -> Browser.Tabs.On_updated.remove_listener handler)
    (fun _tab_id _change_info tab -> tab)

let s_enforcement_requested =
  Op.merge8
    (s_initial_preferred_font |. Stream.pipe1 (Op.map (fun _v _i -> ())))
    (s_preferred_font_changed |. Stream.pipe1 (Op.map (fun _v _i -> ())))
    (s_initial_excluded_from_browser_fonts
    |. Stream.pipe1 (Op.map (fun _v _i -> ())))
    (s_excluded_from_browser_fonts_changed
    |. Stream.pipe1 (Op.map (fun _v _i -> ())))
    (s_initial_excluded_from_document_fonts
    |. Stream.pipe1 (Op.map (fun _v _i -> ())))
    (s_excluded_from_document_fonts_changed
    |. Stream.pipe1 (Op.map (fun _v _i -> ())))
    (s_tab_activated
    |. Stream.pipe2
         (Op.map (fun _v _i -> ()))
         (Op.tap (fun _v -> Js.Console.log "activated")))
    (s_tab_updated
    |. Stream.pipe2
         (Op.map (fun _v _i -> ()))
         (Op.tap (fun _v -> Js.Console.log "updated")))

(* TODO: Messes up the icon update the first time. *)
(* let c_current_tab =
   s_enforcement_requested
   |. Stream.pipe1
        (Op.merge_map (fun _v _i ->
             Browser.Tabs.query { active = Some true; currentWindow = Some true }
             |. Stream.from_promise))
   |. Op.hold [||] *)

let _ =
  s_browser_action_activated
  |. Stream.subscribe (fun tab ->
         match Cell.get_value c_preferred_fonts with
         | Browser_fonts ->
           c_excluded_from_browser_fonts
           |. Cell.get_value
           |. update_excluded_domains tab
           |. store_excluded_domains Browser_fonts
         | Document_fonts ->
           c_excluded_from_document_fonts
           |. Cell.get_value
           |. update_excluded_domains tab
           |. store_excluded_domains Document_fonts)

let _ =
  s_enforcement_requested
  |. Stream.subscribe (fun _ ->
         Browser.Tabs.query { active = Some true; currentWindow = Some true }
         |. Promise.Js.toResult
         |. Promise.getOk (fun tabs ->
                match Array.to_list tabs with
                | [] -> ()
                | tab :: _ -> (
                  Js.Console.log tab.url;
                  match Cell.get_value c_preferred_fonts with
                  | Browser_fonts -> (
                    let excluded_set =
                      Cell.get_value c_excluded_from_browser_fonts
                    in
                    match Set.has excluded_set tab.url with
                    | true -> enforce Document_fonts
                    | false -> enforce Browser_fonts)
                  | Document_fonts -> (
                    let excluded_set =
                      Cell.get_value c_excluded_from_document_fonts
                    in
                    match Set.has excluded_set tab.url with
                    | true -> enforce Browser_fonts
                    | false -> enforce Document_fonts)))
         |. ignore)
