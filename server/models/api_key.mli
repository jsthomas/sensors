module type DB = Caqti_lwt.CONNECTION

type t = {
  id : int;
  uuid : string;
}
(* Note: Yojson isn't used here because an API key is shared with the
   frontend as part of the sensor JSON record.*)

val create: unit -> (module DB) -> t Lwt.t
(* Generate a new API key. *)

val touch: string -> (module DB) -> unit Lwt.t
(* Update the last_used timestamp for this key. *)
