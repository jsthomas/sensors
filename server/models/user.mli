module type DB = Caqti_lwt.CONNECTION

type t = { username : string; name : string; sensors : int list }
[@@deriving yojson]

val get : string -> string -> (module DB) -> int option Lwt.t
(* Recover the ID associated with the input username/password pair, or
   None if the username/password combo is invalid.*)

val sensors : int -> (module DB) -> int list Lwt.t
(* Recover a list of the sensor ids associated with this user. *)

val get_user_meta : int -> (module DB) -> t option Lwt.t
(* Recover the metadata associated with a specific user. *)
