open Js_api
open Rxjs
open Common
open Ffext

let domain_name s =
  match s |. URL.make |. URL.get_host with
  | "" -> s
  | host -> host

let default_data = Data.make_default ()

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

let update_excluded_domains curr_set (tab : Browser.tab) =
  let url = domain_name tab.url in
  match Set.has curr_set url with
  | true ->
    Set.delete curr_set url |. ignore;
    curr_set
  | false -> Set.add curr_set url

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

let s_preferred_fonts_updated =
  Op.merge2 s_initial_preferred_font s_preferred_font_changed

let c_preferred_fonts =
  s_preferred_fonts_updated |. Op.hold default_data.default_fonts

let s_excluded_from_browser_fonts_updated =
  Op.merge2 s_initial_excluded_from_browser_fonts
    s_excluded_from_browser_fonts_changed

let c_excluded_from_browser_fonts =
  s_excluded_from_browser_fonts_updated |. Op.hold (Set.empty ())

let s_excluded_from_document_fonts_updated =
  Op.merge2 s_initial_excluded_from_document_fonts
    s_excluded_from_document_fonts_changed

let c_excluded_from_document_fonts =
  s_excluded_from_document_fonts_updated |. Op.hold (Set.empty ())

let s_browser_action_activated =
  Stream.from_event_pattern2
    (fun handler -> Browser.Browser_action.On_clicked.add_listener handler)
    (fun handler _signal ->
      Browser.Browser_action.On_clicked.remove_listener handler)
    (fun tab _on_click_data -> tab)

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
  Op.merge5
    (s_preferred_fonts_updated |. Stream.pipe1 (Op.map (fun _v _i -> ())))
    (s_excluded_from_browser_fonts_updated
    |. Stream.pipe1 (Op.map (fun _v _i -> ())))
    (s_excluded_from_document_fonts_updated
    |. Stream.pipe1 (Op.map (fun _v _i -> ())))
    (s_tab_activated |. Stream.pipe1 (Op.map (fun _v _i -> ())))
    (s_tab_updated |. Stream.pipe1 (Op.map (fun _v _i -> ())))
  |. Stream.pipe3
       (Op.merge_map (fun _v _i ->
            (* NOTE: Do not try to extract query() into a separate stream variable.
               This stream fires only once.
               So a stream needs to be instantiated every time s_enforcement_requested is fired.
               A separate stream variable would instantiate the stream only once.
            *)
            Browser.Tabs.query { active = Some true; currentWindow = Some true }
            |. Stream.from_promise))
       (Op.filter (fun tabs _i -> Array.length tabs > 0))
       (Op.map (fun tabs _i -> Array.get tabs 0))

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
  |. Stream.subscribe (fun tab ->
         let url = domain_name tab.url in
         match Cell.get_value c_preferred_fonts with
         | Browser_fonts -> (
           let excluded_set = Cell.get_value c_excluded_from_browser_fonts in
           match Set.has excluded_set url with
           | true -> enforce Document_fonts
           | false -> enforce Browser_fonts)
         | Document_fonts -> (
           let excluded_set = Cell.get_value c_excluded_from_document_fonts in
           match Set.has excluded_set url with
           | true -> enforce Browser_fonts
           | false -> enforce Document_fonts))
