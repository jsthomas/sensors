module type DB = Caqti_lwt.CONNECTION

module T = Caqti_type
open Caqti_request.Infix
open Ppx_yojson_conv_lib.Yojson_conv.Primitives

type t = {
  username : string; [@key "username"]
  name : string; [@key "name"]
  sensors : int list; [@key "sensors"]
}
[@@deriving yojson]

type user = { id : int; username : string; name : string; password : string }
[@@deriving yojson]

let create_new_user =
  let query =
    T.(tup3 string string string -->! int)
    @:- Printf.sprintf
          {|
      INSERT INTO app_user (username, name, password) 
      VALUES ($1, $2, $3) RETURNING id
    |}
  in
  fun username name password (module Db : DB) ->
    (*TODO: It is not clear here how add of duplicate user names is avoided *)
    let%lwt user_or_error = Db.find query (username, name, password) in
    Caqti_lwt.or_fail user_or_error

let create username name password db =
  let%lwt id = create_new_user username name password db in
  Lwt.return { id; username; name; password }

(* Note: Storing passwords in cleartext is a bad idea in a production app.*)
let get =
  let query =
    T.(tup2 string string -->? int)
    @:- Printf.sprintf
          "SELECT id FROM app_user WHERE username = ? and password = ?"
  in
  fun username password (module Db : DB) ->
    let%lwt user_or_error = Db.find_opt query (username, password) in
    Caqti_lwt.or_fail user_or_error

let sensors =
  let query =
    T.(int -->? int)
    @:- Printf.sprintf "SELECT sensor FROM user_sensor WHERE app_user = ?"
  in
  fun user_id (module Db : DB) ->
    let%lwt user_or_error = Db.collect_list query user_id in
    Caqti_lwt.or_fail user_or_error

let details =
  let query =
    T.(int -->? tup2 string string)
    @:- Printf.sprintf "SELECT username, name FROM app_user WHERE id = ?"
  in
  fun user_id (module Db : DB) ->
    let%lwt details_or_error = Db.find_opt query user_id in
    Caqti_lwt.or_fail details_or_error

let get_user_meta id m =
  let%lwt details = details id m in
  let%lwt sensors = sensors id m in
  Lwt.return
    (Option.map (fun (username, name) -> { username; name; sensors }) details)
