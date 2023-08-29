module type DB = Caqti_lwt.CONNECTION

open Caqti_request.Infix
module T = Caqti_type

type t = { id : int; uuid : string }

let ( >>= ) = Lwt.bind

let create =
  let query =
    (T.unit -->! T.(tup2 T.int T.string))
    @:- "INSERT INTO api_key DEFAULT VALUES RETURNING id, uuid"
  in
  fun () (module Db : DB) ->
    Db.find query () >>= Caqti_lwt.or_fail >>= fun (id, uuid) ->
    Lwt.return { id; uuid }

let touch =
  let query =
    (T.string -->. T.unit)
    @:- Printf.sprintf "UPDATE api_key SET last_used = now() WHERE uuid = $1"
  in
  fun uuid (module Db : DB) -> Db.exec query uuid >>= Caqti_lwt.or_fail
