type date = Ptime.date
type time = Ptime.time

val readings_per_day : int -> int
(* Report the number of readings per day, given an input reading step size, in seconds. *)

val date_of_string_opt : string -> Ptime.date option
val string_of_date : date -> string

val today : unit -> date

val yojson_of_date : date -> [> `String of string]
val date_of_yojson : [> `String of string] -> date

val datetime_of_epoch_sec : int -> (date * time) option

val bin: time -> int -> int
(* Given a time record and step size, report the index of the bin containing the time.
   Examples:
      time = (1, 20, 15)  i.e. "01:20:15 AM UTC"
      step = 3600         i.e. "60 minute timestep"
      bin = 1             i.e. the second time bin for the day.
*)
