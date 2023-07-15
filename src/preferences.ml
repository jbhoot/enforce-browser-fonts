open Dom_api
open Common
open Rxjs

(*
. bg
  . (initial_state, state_change) -> (icon, tooltip, about_config)
  . browserAction.clicked -> (state_change) -> (save website to excluded or included)
*)

let defaults = Data.make_default ()

let s_initial_config =
  defaults |. Data.serialise |. Storage.Local.get |. Stream.from_promise

let s_initial_default_font =
  s_initial_config
  |. Stream.pipe2
       (Op.map (fun v _i -> Data.deserialise v))
       (Op.map (fun v _i -> v.Data.default_fonts))

let _ =
  Stream.subscribe s_initial_default_font (fun v ->
      let input_id = Data.Font_type.to_string v in
      document
      |. Document.get_element_by_id input_id
      |. InputElement.from_element
      |. InputElement.set_checked true)

(* TODO: Find a good way to use the data in the changes event itself,
   instead of dumping it and fetching values from storage again. *)
(* TODO: defaults shouldn't have to be passed here and also in s_initial_config *)
let c_config_changed =
  Stream.from_event_pattern2
    (fun handler -> Common.Storage.On_changed.add_listener handler)
    (fun handler _signal -> Common.Storage.On_changed.remove_listener handler)
    (fun _changes _area_name ->
      Js.Console.log "changed";
      ())
  |. Stream.pipe1
       (Op.merge_map (fun _unit _i ->
            defaults
            |. Data.serialise
            |. Storage.Local.get
            |. Stream.from_promise))
  |. Op.hold (defaults |. Data.serialise)

let s_document_font_selected =
  document
  |. Document.get_element_by_id
       (Data.Font_type.to_string Data.Font_type.Document_fonts)
  |. InputElement.from_element
  |. Stream.from_event_change ~opts:None

let s_browser_font_selected =
  document
  |. Document.get_element_by_id
       (Data.Font_type.to_string Data.Font_type.Browser_fonts)
  |. InputElement.from_element
  |. Stream.from_event_change ~opts:None

let s_default_font_changed =
  Op.merge2 s_browser_font_selected s_document_font_selected
  |. Stream.pipe1
       (Op.map (fun ev _i ->
            Generic_ev.current_target ev
            |. InputElement.get_value
            |. Data.Font_type.from_string))

(* In the current API design, Storage.Local.set has only one form: it accepts the full storage record.
   So it becomes necessary to construct a new config object to save whenever default_font input changes.
*)
let s_result =
  s_default_font_changed
  |. Stream.pipe1
       (Op.withLatestFrom c_config_changed (fun s_v c_v ->
            let d_c_v = Data.deserialise c_v in
            { Data.default_fonts = s_v
            ; browser_fonts_excludes = d_c_v.browser_fonts_excludes
            ; document_fonts_excludes = d_c_v.document_fonts_excludes
            }))

let _ =
  s_result
  |. Stream.subscribe (fun v ->
         Js.Console.log (Data.serialise v);
         v |. Data.serialise |. Storage.Local.set |. ignore)
