module Set = struct
  type 'a t

  external empty : unit -> 'a t = "Set" [@@mel.new]
  external from_array : 'a array -> 'a t = "Set" [@@mel.new]
  external from_value : 'a -> 'a t = "Set" [@@mel.new]
  external has : 'a t -> 'a -> bool = "has" [@@mel.send]
  external size : 'a t -> int = "size" [@@mel.send]
  external add : 'a t -> 'a -> 'a t = "add" [@@mel.send]
  external clear : 'a t -> unit = "clear" [@@mel.send]
  external delete : 'a t -> 'a -> bool = "delete" [@@mel.send]

  external for_each : 'a t -> ('a -> 'a -> 'a t -> unit) -> unit = "forEach"
    [@@mel.send]

  let to_array t =
    let arr = [||] in
    for_each t (fun v _k _s -> Js.Array.push ~value:v arr |. ignore);
    arr
end

module URL = struct
  type t

  external make : string -> t = "URL" [@@mel.new]
  external get_host : t -> string = "host" [@@mel.get]
end
