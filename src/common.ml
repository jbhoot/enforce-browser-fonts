(* Structure of the storage object
   Its a bit weird, but it is what it is now. Cannot change to keep backward comptability.

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

  type exclude = { exclude : string array }

  type t_whole =
    { defaultFonts : string [@bs.as "default-fonts"]
    ; browserFonts : exclude [@bs.as "browser-fonts"]
    ; documentFonts : exclude [@bs.as "document-fonts"]
    }

  type t_partial =
    { defaultFonts : string [@bs.as "default-fonts"] [@bs.optional]
    ; browserFonts : exclude [@bs.as "browser-fonts"] [@bs.optional]
    ; documentFonts : exclude [@bs.as "document-fonts"] [@bs.optional]
    }
  [@@bs.deriving abstract]

  type 'a diff =
    { oldValue : 'a option
    ; newValue : 'a option
    }

  type t_change =
    { defaultFonts : string diff option [@bs.as "default-fonts"]
    ; browserFonts : exclude diff option [@bs.as "browser-fonts"]
    ; documentFonts : exclude diff option [@bs.as "document-fonts"]
    }
end

module Storage = Ffext.Make_storage (Storage_types)
