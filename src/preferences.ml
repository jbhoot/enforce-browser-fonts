(* open Dom_api *)
open Common
open Rxjs

(*
. Prefs
  . initial to input
  . change to save
  . No error handling required
. bg
  . (initial_state, state_change) -> (icon, tooltip, about_config)
  . browserAction.clicked -> (state_change) -> (save website to excluded or included)
*)

let s_initial_config =
  Types.make_default ()
  |. Types.serialise
  |. Storage.Local.get
  |. Stream.from_promise
  |. Stream.pipe1 (Op.map (fun v _i -> Types.deserialise v))

type x =
  [ `Document_fonts [@bs.as "document-fonts"]
  | `Browser_fonts [@bs.as "browser-fonts"]
  ]
[@@bs.deriving jsConverter]

let a : x = `Document_fonts
