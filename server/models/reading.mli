module type DB = Caqti_lwt.CONNECTION

type readings = float option array [@@deriving yojson]

type t = {
  sensor_id: int;
  occurred: Ptime.date;
  readings: readings
} [@@deriving yojson]

val empty : Sensor.t -> Ptime.date -> t
(* Create an empty set of readings for the input sensor / date combination. *)

val insert : t -> (module DB) -> unit Lwt.t
(* Record a full set of daily measurments for the input sensor / date combination.
   If a record is already present with the same date, it will be overwritten. *)

val read_range : int -> int -> Ptime.date -> Ptime.date -> (module DB) -> t list Lwt.t
(* Retrieve all of the readings for a given sensor between two dates. *)

val read_day : int -> Ptime.date -> (module DB) -> t option Lwt.t
(* Retrieve the readings associated with a given sensor / date
   combination (without validating user ownership). *)

val overwrite : t -> readings -> t
(* Form a new record by replacing existing measurements with ones in
   the input array, provided they are not null.  *)
