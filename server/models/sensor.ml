module type DB = Caqti_lwt.CONNECTION
module R = Caqti_request
module T = Caqti_type

let (>>=) = Lwt.bind

type t = {
  id: int;
  name: string;
  description: string;
  api_key: string;
  step: int;
} [@@deriving yojson]


let create_sensor  =
  let query =
    R.find T.(tup4 T.string T.string T.int T.int) T.int
      {|
       INSERT INTO sensor (name, description, api_key, step)
       VALUES ($1, $2, $3, $4) RETURNING id
      |} in
  fun name description key_id step (module Db : DB) ->
    let%lwt result = Db.find query (name, description, key_id, step) in
    Caqti_lwt.or_fail result


let create_user_relationship =
  let query =
    R.exec T.(tup2 T.int T.int)
      "INSERT INTO user_sensor (app_user, sensor) VALUES ($1, $2)" in
  fun user_id sensor_id (module Db: DB) ->
    let%lwt result = Db.exec query (user_id, sensor_id) in
    Caqti_lwt.or_fail result


let create user_id name description step db =
  let%lwt k = Api_key.create () db in
  let%lwt id = create_sensor name description k.id step db in
  let%lwt _ = create_user_relationship user_id id db in
  Lwt.return {id; name; description; api_key=k.uuid; step}


let get =
  let query =
    R.find_opt T.(tup2 T.int T.int) T.(tup4 T.string T.string T.string T.int)
      {|
       SELECT s.name, s.description, k.uuid, s.step
       FROM sensor s
       INNER JOIN user_sensor us
          ON us.sensor = s.id AND us.app_user = $1 AND us.sensor = $2
       INNER JOIN api_key k
          ON s.api_key = k.id
      |}
  in
  fun user_id sensor_id (module Db: DB) ->
    Db.find_opt query (user_id, sensor_id)
    >>= Caqti_lwt.or_fail
    >>= (fun details_or_error ->
        Lwt.return (
          Option.map (fun (name, description, api_key, step) ->
              {id=sensor_id; name; description; api_key; step})
            details_or_error))


let delete =
  let query =
    R.exec T.(tup2 T.int T.int)
      {|
       DELETE FROM sensor WHERE id IN
       (SELECT s.id FROM
        Sensor s
        INNER JOIN user_sensor us
        ON us.sensor = s.id AND us.app_user = $1 AND us.sensor = $2)
      |}
  in
  fun user_id sensor_id (module Db: DB) ->
    let%lwt result = Db.exec query (user_id, sensor_id) in
    Caqti_lwt.or_fail result


let from_key =
  let query =
    R.collect T.string (T.tup4 T.int T.string T.string T.int)
      {|
      SELECT s.id, s.name, s.description, s.step FROM sensor s
      INNER JOIN api_key k
      ON s.api_key = k.id AND k.uuid = $1
      |}
  in
  fun api_key (module Db: DB) ->
    Db.collect_list query api_key
    >>= Caqti_lwt.or_fail
    >>= (fun details_or_error ->
        Lwt.return (
          List.map (fun (id, name, description, step) -> {id; name; description; api_key; step})
            details_or_error))
