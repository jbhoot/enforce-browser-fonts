(*
  {
    "default-fonts": "browser-fonts",
    "browser-fonts": { "exclude": [] },
    "document-fonts": { "exclude": [] }
  }
*)

module Storage_types = struct
  type keys =
    [ `defaultFonts
    | `browserFonts
    | `documentFonts
    ]

  type excluded_urls = { exclude : string array }

  type t_whole =
    { defaultFonts : string [@bs.as "default-fonts"]
    ; browserFonts : excluded_urls [@bs.as "browser-fonts"]
    ; documentFonts : excluded_urls [@bs.as "document-fonts"]
    }

  type t_partial =
    { defaultFonts : string [@bs.as "default-fonts"] [@bs.optional]
    ; browserFonts : excluded_urls [@bs.as "browser-fonts"] [@bs.optional]
    ; documentFonts : excluded_urls [@bs.as "document-fonts"] [@bs.optional]
    }
  [@@bs.deriving abstract]

  type 'a diff =
    { oldValue : 'a option
    ; newValue : 'a option
    }

  type t_change =
    { defaultFonts : string diff [@bs.as "default-fonts"]
    ; browserFonts : excluded_urls diff [@bs.as "browser-fonts"]
    ; documentFonts : excluded_urls diff [@bs.as "document-fonts"]
    }
end

module Storage = Ffext.Make_storage (Storage_types)
