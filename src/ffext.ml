module Browser = struct
  type tab_id

  type tab =
    { id : tab_id
    ; pinned : bool
    ; url : string
    }

  module Browser_action = struct
    type icon_details = { path : string }
    type title_details = { title : string }

    external set_icon : icon_details -> (unit, unit) Promise.Js.t = "setIcon"
      [@@bs.val] [@@bs.scope "browser", "browserAction"]

    external set_title : title_details -> (unit, unit) Promise.Js.t = "setTitle"
      [@@bs.val] [@@bs.scope "browser", "browserAction"]

    module On_clicked = struct
      (* TODO: Turn modifiers into a polymorphic type *)
      type on_click_data =
        { modifiers : string array (* e.g,. ["Shift"] *)
        ; button : int (* Mouse button code *)
        }

      external add_listener : (tab -> on_click_data -> unit) -> unit
        = "addListener"
        [@@bs.val] [@@bs.scope "browser", "browserAction", "onClicked"]

      external remove_listener : (tab -> on_click_data -> unit) -> unit
        = "removeListener"
        [@@bs.val] [@@bs.scope "browser", "browserAction", "onClicked"]
    end
  end

  module Runtime = struct
    (* todo: turn this into a functor *)

    type message_sender =
      { tab : tab
      ; id : string
      }

    external send_message_internally : 'msg -> ('resp_msg, string) Promise.Js.t
      = "sendMessage"
      [@@bs.val] [@@bs.scope "browser", "runtime"]

    module On_message = struct
      external add_listener :
        ('msg -> message_sender -> ('resp_msg, string) Promise.Js.t) -> unit
        = "addListener"
        [@@bs.val] [@@bs.scope "browser", "runtime", "onMessage"]

      external remove_listener :
        ('msg -> message_sender -> ('resp_msg, string) Promise.Js.t) -> unit
        = "removeListener"
        [@@bs.val] [@@bs.scope "browser", "runtime", "onMessage"]
    end
  end

  module Tabs = struct
    type update_properties = { pinned : bool }

    external update : tab_id -> update_properties -> (tab, string) Promise.Js.t
      = "update"
      [@@bs.val] [@@bs.scope "browser", "tabs"]

    type query_obj =
      { active : bool option
      ; currentWindow : bool option
      }

    external query : query_obj -> (tab array, string) Promise.Js.t = "query"
      [@@bs.val] [@@bs.scope "browser", "tabs"]

    module On_activated = struct
      type active_info =
        { previousTabId : int
        ; tabId : int
        ; windowId : int
        }

      external add_listener : (active_info -> unit) -> unit = "addListener"
        [@@bs.val] [@@bs.scope "browser", "tabs", "onActivated"]

      external remove_listener : (active_info -> unit) -> unit
        = "removeListener"
        [@@bs.val] [@@bs.scope "browser", "tabs", "onActivated"]
    end

    module On_updated = struct
      type filter =
        { urls : string array option
        ; properties : string array option
        ; tabId : int option
        ; windowId : int option
        }

      type change_info =
        { (* NOTE: Incomplete record *)
          pinned : bool option
        ; title : string option
        ; url : string option
        }

      external add_listener : (int -> change_info -> tab -> unit) -> unit
        = "addListener"
        [@@bs.val] [@@bs.scope "browser", "tabs", "onUpdated"]

      external add_listener_with_filter :
        (int -> change_info -> tab -> unit) -> filter -> unit = "addListener"
        [@@bs.val] [@@bs.scope "browser", "tabs", "onUpdated"]

      external remove_listener : (int -> change_info -> tab -> unit) -> unit
        = "removeListener"
        [@@bs.val] [@@bs.scope "browser", "tabs", "onUpdated"]
    end
  end

  module Browser_settings = struct
    module Use_document_fonts = struct
      type t = { value : bool }

      external set : t -> (bool, bool) Promise.Js.t = "set"
        [@@bs.val] [@@bs.scope "browser", "browserSettings", "useDocumentFonts"]
    end
  end
end

module type Storage_args_sig = sig
  type keys (* Polymorphic variant of the name of the keys used in t_whole *)
  type t_whole (* a record of keys and values stored in Storage *)
  type t_partial
  (* same structure as t_whole, but tagged with [@bs.optional] and [@@bs.deriving abstract] to allow for optional keys *)

  type 'a diff =
    { oldValue : 'a option
    ; newValue : 'a option
    }

  type t_change
end

module Make_storage (Args : Storage_args_sig) = struct
  type area_name =
    [ `sync
    | `local
    | `managed
    ]

  module Local = struct
    external get : Args.t_whole -> (Args.t_whole, string) Promise.Js.t = "get"
      [@@bs.val] [@@bs.scope "browser", "storage", "local"]

    external set : Args.t_partial -> (unit, string) Promise.Js.t = "set"
      [@@bs.val] [@@bs.scope "browser", "storage", "local"]

    external clear : unit -> (unit, string) Promise.Js.t = "clear"
      [@@bs.val] [@@bs.scope "browser", "storage", "local"]

    external remove : Args.keys array -> (unit, string) Promise.Js.t = "remove"
      [@@bs.val] [@@bs.scope "browser", "storage", "local"]
  end

  module On_changed = struct
    (*
        A set() call produces a diff object which contains only those keys of all the keys of the Storage object, which were used in that set() call:
          set({key1: val1, key2: val2})
          => { key1: {oldValue: oVal1, newValue: nVal1}
             , key2: {oldValue: oVal2, newValue: nVal2} }

        A set() called on a key that does not exist in the Storage at the time of the call uses `undefined` as the `oldValue` for that key.
          set({newKey: val})
          => {newKey: {oldValue: undefined, newValue: val}}

        A remove() call produces a diff object which contains only those keys which were provided in that remove() call. A key's diff does not contain `newValue` key.
          remove("key1")
          => { key1: {oldValue: oVal1}}

        remove() called on a key that does not exist in the Storage at the time of the call does not trigger an onChanged event.

        clear() produces a diff object containing all the Storage keys. A key's diff does not contain `newValue`.
          {key: {oldValue: value}}

        clear() called on an empty Storage does not trigger an onChanged event.
      *)

    external add_listener : (Args.t_change -> area_name -> unit) -> unit
      = "addListener"
      [@@bs.val] [@@bs.scope "browser", "storage", "onChanged"]

    external remove_listener : (Args.t_change -> area_name -> unit) -> unit
      = "removeListener"
      [@@bs.val] [@@bs.scope "browser", "storage", "onChanged"]
  end
end
