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
    { defaultFonts : string [@mel.as "default-fonts"]
    ; browserFonts : exclude [@mel.as "browser-fonts"]
    ; documentFonts : exclude [@mel.as "document-fonts"]
    }

  type t_partial =
    { defaultFonts : string option; [@mel.as "default-fonts"] [@mel.optional]
    browserFonts : exclude option; [@mel.as "browser-fonts"] [@mel.optional]
    documentFonts : exclude option; [@mel.as "document-fonts"] [@mel.optional]
    }
  [@@deriving jsProperties]

  type 'a diff =
    { oldValue : 'a option
    ; newValue : 'a option
    }

  type t_change =
    { defaultFonts : string diff option [@mel.as "default-fonts"]
    ; browserFonts : exclude diff option [@mel.as "browser-fonts"]
    ; documentFonts : exclude diff option [@mel.as "document-fonts"]
    }
end

module Storage = Ffext.Make_storage (Storage_types)
