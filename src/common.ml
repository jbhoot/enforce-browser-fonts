(* { "default-fonts": "browser-fonts", "browser-fonts": { "exclude": [] },
   "document-fonts": { "exclude": [] } } *)

module Storage_args = struct
  type excluded_urls = { exclude : string array }

  type t =
    { defaultFonts : string [@bs.as "default-fonts"]
    ; browserFonts : excluded_urls [@bs.as "browser-fonts"]
    ; documentFonts : excluded_urls [@bs.as "document-fonts"]
    }

  type 'v change =
    { oldValue : 'v option
    ; newValue : 'v option
    }

  type changes =
    { defaultFontsChange : string change [@bs.as "default-fonts"]
    ; browserFontsChange : excluded_urls change [@bs.as "browser-fonts"]
    ; documentFontsChange : excluded_urls change [@bs.as "document-fonts"]
    }
end

module Storage = Ffext.Browser.Storage (Storage_args)
