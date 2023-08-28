module type DB = Caqti_lwt.CONNECTION
open Caqti_request.Infix
module T = Caqti_type

type t = {
  username: string [@key "username"];
  name: string [@key "name"];
  sensors: int list [@key "sensors"];
} [@@deriving yojson]


(* Note: Storing passwords in cleartext is a bad idea in a production app.*)
let get =
  let query =
    (T.(tup2 T.string T.string) -->? T.int)
      @:- Printf.sprintf "SELECT id FROM app_user WHERE username = ? and password = ?" in
  fun username password (module Db : DB) ->
    let%lwt user_or_error = Db.find_opt query (username, password) in
    Caqti_lwt.or_fail user_or_error


let sensors =
  let query =
    (T.int -->? T.int )
      @:- Printf.sprintf "SELECT sensor FROM user_sensor WHERE app_user = ?" in
  fun user_id (module Db : DB) ->
    let%lwt user_or_error = Db.collect_list query user_id in
    Caqti_lwt.or_fail user_or_error


let details =
  let query =
    (T.int -->? T.(tup2 T.string T.string))
    @:- Printf.sprintf "SELECT username, name FROM app_user WHERE id = ?" in
  fun user_id (module Db : DB) ->
    let%lwt details_or_error = Db.find_opt query user_id in
    Caqti_lwt.or_fail details_or_error


let get_user_meta id m =
  let%lwt details = details id m in
  let%lwt sensors = sensors id m in
  Lwt.return (Option.map (fun (username, name) -> {username; name; sensors}) details)
