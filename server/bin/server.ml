module type DB = Caqti_lwt.CONNECTION
module R = Caqti_request
module T = Caqti_type

module Time = Lib.Time
module Reading = Models.Reading
module Sensor = Models.Sensor

let (>>=) = Lwt.bind
let (>>=?) = Option.bind
let (|>?) a b = Option.map b a

let int_of_string x =
  x |> Int32.of_string |> Int32.to_int

let int_of_string_opt x =
  x |> Int32.of_string_opt |>? Int32.to_int

let json_response ?status x =
  x |> Yojson.Safe.to_string |> Dream.json ?status


type error_doc = {
  error : string;
} [@@deriving yojson]


type login_doc = {
  username : string;
  password : string;
} [@@deriving yojson]


let json_receiver json_parser handler request =
  let%lwt body = Dream.body request in
  let parse =
    try
      Some (body
      |> Yojson.Safe.from_string
      |> json_parser)
    with _ ->
      None
  in
  match parse with
  | Some doc -> handler doc request
  | None ->
    { error="Received invalid JSON input." }
    |> yojson_of_error_doc
    |> json_response ~status: `Bad_Request


let login =
  let login_base login_doc request =
    let%lwt user_id = Dream.sql request
        (Models.User.get login_doc.username login_doc.password) in
    match user_id with
    | Some id ->
      let%lwt () = Dream.invalidate_session request in
      let%lwt () = Dream.put_session "user" (Int.to_string id) request in
      Dream.empty `OK
    | None -> Dream.empty `Forbidden
  in
  json_receiver login_doc_of_yojson login_base


let logout request =
  let%lwt () = Dream.invalidate_session request in
  Dream.empty `OK


let login_required h request =
  match Dream.session "user" request with
  | None -> Dream.empty `Unauthorized
  | _ -> h request


let get_user_id request =
  (* Retrieve the user's ID from the session. This is only safe to use
     for handlers within the API/login_required scope.*)
  Dream.session "user" request
  |> Option.get
  |> int_of_string


let user request =
  let%lwt u = get_user_id request
              |> Models.User.get_user_meta
              |> Dream.sql request in
  match u with
  | None ->
    Dream.empty `Not_Found
  | Some details ->
    Models.User.yojson_of_t details
    |> json_response


type sensor_create_doc = {
  name : string;
  description : string;
  step: int
}[@@deriving yojson]


let id_validator key handler request =
  let sensor_id = Dream.param key request |> int_of_string_opt in
  match sensor_id with
  | None -> Dream.empty `Bad_Request
  | Some m_id ->
    handler m_id request


let create_sensor =
  let create spec request =
    let user_id = get_user_id request in
    let%lwt sensor =
      Dream.sql request (Sensor.create user_id spec.name spec.description spec.step) in
    Sensor.yojson_of_t sensor
    |> json_response
  in
  json_receiver sensor_create_doc_of_yojson create


let read_sensor sensor_id request =
  let user_id = get_user_id request in
  match%lwt Dream.sql request (Sensor.get user_id sensor_id) with
  | None -> Dream.empty `Not_Found
  | Some m ->
    Sensor.yojson_of_t m
    |> json_response


let delete_sensor sensor_id request =
  let user_id = get_user_id request in
  let%lwt _ = Dream.sql request (Sensor.delete user_id sensor_id) in
  Dream.empty `OK


let date_query_param key ~default request =
  Dream.query key request
    >>=? Time.date_of_string_opt
    |> Option.value ~default


let get_readings sensor_id request =
  let today = Time.today () in
  let user_id = get_user_id request in
  let start_d = date_query_param "start" ~default:today request in
  let end_d = date_query_param "end" ~default:today request in
  let%lwt readings = Dream.sql request (Reading.read_range user_id sensor_id start_d end_d) in
  `List (List.map Reading.yojson_of_t readings)
  |> json_response


type readings_create_doc = {
  occurred : Time.date;
  readings : Reading.readings;
}[@@deriving yojson]


let write_readings sensor_id =
  let write create_obj request =
    let user_id = get_user_id request in
    match%lwt Dream.sql request (Sensor.get user_id sensor_id) with
    | None -> Dream.empty `Not_Found
    | Some sensor ->
      let actual = Array.length create_obj.readings in
      let expected = Time.readings_per_day sensor.step in
      if actual = expected  then
        let r: Reading.t = {
          sensor_id=sensor.id;
          occurred=create_obj.occurred;
          readings=create_obj.readings
        } in
        let%lwt _ = Dream.sql request (Reading.insert r) in
        Dream.empty `OK
      else
        let message = Printf.sprintf
            "Incorrect number of readings. Actual: %d, Expected: %d"
            actual expected in
        let e = { error = message } in
        yojson_of_error_doc e
        |> json_response ~status:`Bad_Request
  in
  json_receiver readings_create_doc_of_yojson write


let api_key_required handler request =
  match Dream.header "Authorization" request with
  | None -> Dream.empty `Bad_Request
  | Some key ->
    let key = Stringext.replace_all ~pattern:"Bearer " ~with_:"" key in
    let%lwt sensors = key |> Sensor.from_key |> Dream.sql request in
    match sensors with
    | [] -> Dream.empty `Forbidden
    | _ ->
      let%lwt _ = Models.Api_key.touch key |> Dream.sql request in
      handler sensors request


type sensor_upload_rec = {
  time : int;  (* UTC epoch timestamp. *)
  value: float;
}[@@deriving yojson]


type sensor_upload_doc = sensor_upload_rec list [@@deriving yojson]

let sensor_upload sensor_ids request =
  (* Write the data in the JSON body of the request to each sensor's
     database records.

   Sensor data is posted as list of UTC time / float pairs, which must
     be converted into the date/array format used in the Reading
     model.*)
  let store_one doc request (sensor: Sensor.t) =
    let n = Time.readings_per_day sensor.step in
    let table = Hashtbl.create 7 in
    let insert d t v =
      let bin = Time.bin t sensor.step in
      let a = match Hashtbl.find_opt table d with
        | Some array -> array
        | None ->
          let u: float option array = Array.make n None in
          Hashtbl.add table d u;
          u
      in
      Array.set a bin v
    in
    let add record =
      match Time.datetime_of_epoch_sec record.time with
      | Some (d,t) -> insert d t (Some record.value)
      | None -> ()
    in
    let persist (d, readings) =
      let%lwt existing = Dream.sql request (Reading.read_day sensor.id d) in
      let record: Reading.t = match existing with
        | None -> {sensor_id=sensor.id; occurred=d; readings}
        | Some row -> Reading.overwrite row readings
      in
      Dream.sql request (Reading.insert record)
    in
    List.iter add doc;
    Hashtbl.to_seq table |> List.of_seq |> Lwt_list.iter_s persist
  in

  let upload (sensors: Sensor.t list) doc request =
    let%lwt _ = Lwt_list.iter_s (store_one doc request) sensors in
    Dream.empty `OK
  in
  json_receiver sensor_upload_doc_of_yojson (upload sensor_ids) request


let version _request =
  Dream.html "Sensors v0.0.0"


let () =
  Dream.run ~interface:"0.0.0.0"
  @@ Dream.logger
  @@ Dream.sql_pool "postgresql://sensors@127.0.0.1/sensors"
  @@ Dream.sql_sessions
  @@ Dream.router [
    Dream.get "/" version;
    Dream.get "/version" version;

    Dream.post "/api/login" login;
    Dream.post "/api/logout" logout;

    Dream.scope "/api" [login_required] [
      Dream.get "/user" user;
      Dream.scope "/sensor" [] [
        Dream.post "/" create_sensor;
        Dream.get "/:sensor_id" @@ id_validator "sensor_id" read_sensor;
        Dream.delete "/:sensor_id" @@ id_validator "sensor_id" delete_sensor;

        Dream.post "/:sensor_id/readings" @@ id_validator "sensor_id" write_readings;
        Dream.get "/:sensor_id/readings" @@ id_validator "sensor_id" get_readings
      ]
    ];

    Dream.scope "/sensor" [] [
      Dream.post "/upload" @@ api_key_required sensor_upload;
    ]
  ]
  @@ Dream.not_found
