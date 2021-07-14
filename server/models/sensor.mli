module type DB = Caqti_lwt.CONNECTION

type t = {
  id: int;
  name: string;
  description: string;
  api_key: string;
  step: int;  (* Number of seconds between readings. *)
} [@@deriving yojson]


val create: int -> string -> string -> int -> (module DB) -> t Lwt.t
(* Generate a new sensor record for a given user ID, sensor name,
   description, and step size. *)

val get : int -> int -> (module DB) -> t option Lwt.t
(* `get user_id sensor_id` retrieves the metadata of a sensor
   with primary key sensor_id, provided that sensor is owned by the user
   identified by user_id. *)

val delete : int -> int -> (module DB) -> unit Lwt.t
(* `delete user_id sensor_id` deletes the sensor record with primary key
   sensor_id, provided that sensor is owned by the user identified by
   user_id. Because of foreign key relationships, this also deletes
   the time series data associated with the sensor.*)

val from_key : string -> (module DB) -> t list Lwt.t
(* Recover the primary keys of all of the sensors accessible from
   the input API key. *)
