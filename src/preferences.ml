open Dom_api
open Common
open Rxjs

let defaults = Data.make_default ()

let s_initial_preferred_font =
  defaults
  |. Data.serialise
  |. Storage.Local.get
  |. Stream.from_promise
  |. Stream.pipe2
       (Op.map (fun v _i -> Data.deserialise v))
       (Op.map (fun v _i -> v.Data.default_fonts))

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

let s_preferred_font_changed =
  Op.merge2 s_browser_font_selected s_document_font_selected
  |. Stream.pipe1
       (Op.map (fun ev _i ->
            Generic_ev.current_target ev
            |. InputElement.get_value
            |. Data.Font_type.from_string))

let _ =
  s_initial_preferred_font
  |. Stream.subscribe (fun v ->
         let input_id = Data.Font_type.to_string v in
         document
         |. Document.get_element_by_id input_id
         |. InputElement.from_element
         |. InputElement.set_checked true)

let _ =
  s_preferred_font_changed
  |. Stream.subscribe (fun v ->
         Common.Storage_types.t_partial ~defaultFonts:(Data.Font_type.to_string v) ()
         |. Storage.Local.set
         |. ignore)
