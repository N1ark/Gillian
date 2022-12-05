module type S = sig
  type tl_ast
  type debug_state

  module Inspect : sig
    type debug_state_view [@@deriving yojson]

    val get_debug_state : debug_state -> debug_state_view

    val get_unification :
      Logging.ReportId.t -> debug_state -> Logging.ReportId.t * Unify_map.t
  end

  val launch : string -> string option -> (debug_state, string) result

  val jump_to_id :
    string -> Logging.ReportId.t -> debug_state -> (unit, string) result

  val jump_to_start : debug_state -> unit
  val step_in : ?reverse:bool -> debug_state -> stop_reason
  val step : ?reverse:bool -> debug_state -> stop_reason

  val step_specific :
    string ->
    Exec_map.Packaged.branch_case option ->
    Logging.ReportId.t ->
    debug_state ->
    (stop_reason, string) result

  val step_out : debug_state -> stop_reason
  val run : ?reverse:bool -> ?launch:bool -> debug_state -> stop_reason
  val start_proc : string -> debug_state -> (stop_reason, string) result
  val terminate : debug_state -> unit
  val get_frames : debug_state -> frame list
  val get_scopes : debug_state -> scope list
  val get_variables : int -> debug_state -> Variable.t list
  val get_exception_info : debug_state -> exception_info
  val set_breakpoints : string option -> int list -> debug_state -> unit
end

module type Make = functor
  (ID : Init_data.S)
  (PC : ParserAndCompiler.S with type init_data = ID.t)
  (V : Verifier.S with type SPState.init_data = ID.t and type annot = PC.Annot.t)
  (Lifter : Debugger_lifter.S
              with type memory = V.SAInterpreter.heap_t
               and type memory_error = V.SPState.m_err_t
               and type tl_ast = PC.tl_ast
               and type cmd_report = V.SAInterpreter.Logging.ConfigReport.t
               and type annot = PC.Annot.t)
  -> S

module type Intf = sig
  (** @canonical Gillian.Debugger.S *)
  module type S = S

  (**/**)

  module type Make = Make

  (**/**)

  (** @canonical Gillian.Debugger.Make *)
  module Make : Make
end