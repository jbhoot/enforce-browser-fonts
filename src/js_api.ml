module Set = struct
  type 'a t

  external empty : unit -> 'a t = "Set" [@@bs.new]
  external from_array : 'a array -> 'a t = "Set" [@@bs.new]
  external from_value : 'a -> 'a t = "Set" [@@bs.new]
  external has : 'a t -> 'a -> bool = "has" [@@bs.send]
  external size : 'a t -> int = "size" [@@bs.send]
  external add : 'a t -> 'a -> 'a t = "add" [@@bs.send]
  external clear : 'a t -> unit = "clear" [@@bs.send]
  external delete : 'a t -> 'a -> bool = "delete" [@@bs.send]

  external for_each : 'a t -> ('a -> 'a -> 'a t -> unit) -> unit = "forEach"
    [@@bs.send]

  let to_array t =
    let arr = [||] in
    for_each t (fun v _k _s -> Js.Array2.push arr v |. ignore);
    arr
end
