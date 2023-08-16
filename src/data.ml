open Js_api

module Font_type = struct
  type t =
    | Browser_fonts
    | Document_fonts

  let to_string = function
    | Browser_fonts -> "browser-fonts"
    | Document_fonts -> "document-fonts"

  let from_string = function
    | "browser-fonts" -> Browser_fonts
    | "document-fonts" -> Document_fonts
    | _ -> Browser_fonts
end

type t =
  { default_fonts : Font_type.t
  ; browser_fonts_exclude : string Set.t
  ; document_fonts_exclude : string Set.t
  }

let serialise t : Common.Storage_types.t_whole =
  { defaultFonts = t.default_fonts |. Font_type.to_string
  ; browserFonts = { exclude = t.browser_fonts_exclude |. Set.to_array }
  ; documentFonts = { exclude = t.document_fonts_exclude |. Set.to_array }
  }

let deserialise (serialisedT : Common.Storage_types.t_whole) =
  { default_fonts = serialisedT.defaultFonts |. Font_type.from_string
  ; browser_fonts_exclude = serialisedT.browserFonts.exclude |. Set.from_array
  ; document_fonts_exclude =
      serialisedT.documentFonts.exclude |. Set.from_array
  }

let make_default () =
  { default_fonts = Browser_fonts
  ; browser_fonts_exclude = Set.empty ()
  ; document_fonts_exclude = Set.empty ()
  }
