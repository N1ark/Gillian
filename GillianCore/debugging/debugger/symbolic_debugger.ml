module Make
    (ID : Init_data.S)
    (PC : ParserAndCompiler.S with type init_data = ID.t)
    (Verification : Verifier.S
                      with type SPState.init_data = ID.t
                       and type annot = PC.Annot.t)
    (Lifter : Debugger_lifter.S
                with type memory = Verification.SAInterpreter.heap_t
                 and type memory_error = Verification.SPState.m_err_t
                 and type tl_ast = PC.tl_ast
                 and type cmd_report =
                  Verification.SAInterpreter.Logging.ConfigReport.t
                 and type annot = PC.Annot.t
                 and type init_data = PC.init_data
                 and type pc_err = PC.err) =
struct
  open Base_debugger.Premake (ID) (PC) (Verification) (Lifter)

  module Impl : Debugger_impl = struct
    type proc_state_ext = unit
    type debug_state_ext = unit

    let preprocess_prog ~no_unfold:_ prog = prog
    let init _ = ()
    let init_proc _ _ = ()

    let launch_proc ~proc_name (debug_state : debug_state_ext base_debug_state)
        =
      let prog =
        match MP.init_prog debug_state.prog with
        | Error _ -> failwith "Creation of matching plans failed"
        | Ok prog -> prog
      in
      Verification.SAInterpreter.init_evaluate_proc
        (fun x -> x)
        prog proc_name []
        (State.init debug_state.init_data)

    module Match = struct
      let match_final_cmd _ ~proc_name:_ _ _ = []
      let get_matches _ _ _ = []

      let get_match_map _ _ =
        failwith "Can't get matching in symbolic debugging!"
    end
  end

  include Make (Impl)
end
