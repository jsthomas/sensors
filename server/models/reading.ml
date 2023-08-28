module type DB = Caqti_lwt.CONNECTION
module Time = Lib.Time
module T = Caqti_type

open Caqti_request.Infix
open Ppx_yojson_conv_lib.Yojson_conv.Primitives


type readings = float option array [@@deriving yojson]

type t = {
  sensor_id: int;
  occurred: Time.date;
  readings: readings
} [@@deriving yojson]


let empty (s: Sensor.t) occurred =
  let n = Time.readings_per_day 900 in  (* FIXME: Sensor step sizes. *)
  let readings = Array.init n (fun _ -> None) in
  { sensor_id=s.id; occurred; readings }


let sql_readings =
  let encode (a: readings) =
    Ok (a |> yojson_of_readings |> Yojson.Safe.to_string)
  in
  let decode text =
    Ok (text |> Yojson.Safe.from_string |> readings_of_yojson)
  in
  T.(custom ~encode ~decode string)


let sql_date =
  let encode (d: Time.date) = Ok (Time.string_of_date d) in
  let decode text =
    match Time.date_of_string_opt text with
    | Some d -> Ok d
    | _ -> Error (Printf.sprintf "Failed to parse date string '%s'." text )
  in
  T.(custom ~encode ~decode string)


let insert =
  let query =
    (T.(tup3 T.int sql_date sql_readings) -->. T.unit)
      @:- Printf.sprintf {|
      INSERT INTO sensor_reading (sensor, occurred, readings)
      VALUES ($1, $2, $3)
      ON CONFLICT (sensor, occurred) DO UPDATE SET readings = $3
      |}
  in
  fun r (module Db: DB) ->
    let%lwt result = Db.exec query (r.sensor_id, r.occurred, r.readings) in
    Caqti_lwt.or_fail result


let read_range =
  let query =
    (T.(tup4 T.int T.int sql_date sql_date) -->? T.(tup2 sql_date sql_readings))
     @:- {|
      SELECT sr.occurred, sr.readings FROM sensor_reading sr
      INNER JOIN user_sensor us ON
        sr.sensor = $2 AND us.sensor = sr.sensor AND us.app_user = $1
      WHERE
        $3 <= sr.occurred and sr.occurred <= $4
      |}
  in
  fun user_id sensor_id start_d end_d (module Db: DB) ->
    let%lwt result = Db.collect_list query (user_id, sensor_id, start_d, end_d) in
    let%lwt tuples = Caqti_lwt.or_fail result in
    let convert = (fun (d, readings) -> {sensor_id; occurred=d; readings}) in
    Lwt.return (List.map convert tuples)


let read_day =
  let query =
   (T.(tup2 T.int sql_date) -->? sql_readings)
     @:- Printf.sprintf {|
      SELECT sr.readings FROM sensor_reading sr
      WHERE
        sr.sensor = $1 AND sr.occurred = $2
      |}
  in
  fun sensor_id d (module Db: DB) ->
    let%lwt result = Db.find_opt query (sensor_id, d) in
    let%lwt tuples = Caqti_lwt.or_fail result in
    let convert = (fun readings -> {sensor_id; occurred=d; readings}) in
    Lwt.return (Option.map convert tuples)


let overwrite {sensor_id; occurred; readings} (a: float option array) =
  let rec optzip x y =
    match x, y with
    | _::xs, Some y::ys -> Some y :: (optzip xs ys)
    | Some x::xs, None::ys -> Some x :: (optzip xs ys)
    | None::xs, None::ys -> None :: (optzip xs ys)
    | _ -> []
  in
  let pairs = optzip (Array.to_list readings) (Array.to_list a) in
  let readings = Array.of_list pairs in
  {sensor_id; occurred; readings=readings}
