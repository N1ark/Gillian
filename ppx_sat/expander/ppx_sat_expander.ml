open Ppxlib
open Ast_builder.Default

module Extension_name = struct
  type t = Sat | Ent

  let to_string = function
    | Sat -> "sat"
    | Ent -> "ent"
end

let ppx_sat_runtime = Lident "Ppx_sat_runtime"
let if_then_else = Ldot (ppx_sat_runtime, "if_then_else")
let if_sure_then_else = Ldot (ppx_sat_runtime, "if_sure_then_else")
let branch_entailment = Ldot (ppx_sat_runtime, "branch_entailment")

let if_fun_fexpr_of_ext = function
  | Extension_name.Sat -> if_then_else
  | Ent -> if_sure_then_else

let match_fun_fexpr_of_ext = function
  | Extension_name.Ent -> branch_entailment
  | Sat -> failwith "Should not get here, match should not be used with 'sat'"

let formula_true_ident = Ldot (ppx_sat_runtime, "true_formula")

let if_fexpr ~ext loc =
  let if_fun = if_fun_fexpr_of_ext ext in
  pexp_ident ~loc (Located.mk ~loc if_fun)

let match_fexpr ~ext loc =
  let match_fun = match_fun_fexpr_of_ext ext in
  pexp_ident ~loc (Located.mk ~loc match_fun)

let to_thunk ~loc exp =
  let any_pattern = ppat_any ~loc in
  pexp_fun ~loc Nolabel None any_pattern exp

let expand_if ~ext ~loc expr then_ else_ =
  let fexpr = if_fexpr ~ext loc in
  pexp_apply ~loc fexpr
    [
      (Nolabel, expr);
      (Labelled "then_branch", to_thunk ~loc then_);
      (Labelled "else_branch", to_thunk ~loc else_);
    ]

let transform_case ~ext ~expr (case : case) =
  let () =
    match case.pc_guard with
    | Some guard ->
        Location.raise_errorf ~loc:guard.pexp_loc
          "pattern guards are not authorized with the '%%%s' extension"
          (Extension_name.to_string ext)
    | None -> ()
  in
  let lhs = case.pc_lhs in
  let formula_expr =
    match lhs.ppat_desc with
    | Ppat_var str_loc ->
        pexp_ident ~loc:str_loc.loc
          (Located.mk ~loc:str_loc.loc (lident str_loc.txt))
    | Ppat_any ->
        let true_expr =
          pexp_ident ~loc:lhs.ppat_loc
            (Located.mk ~loc:lhs.ppat_loc formula_true_ident)
        in
        to_thunk ~loc:lhs.ppat_loc true_expr
    | _ ->
        Location.raise_errorf ~loc:lhs.ppat_loc
          "the '%%%s' extension only works if the pattern is a function name \
           with type Expr.t -> Formula.t, or a '_' pattern"
          (Extension_name.to_string ext)
  in
  let applied = pexp_apply ~loc:lhs.ppat_loc formula_expr [ (Nolabel, expr) ] in
  let rhs = to_thunk ~loc:case.pc_rhs.pexp_loc case.pc_rhs in
  (applied, rhs)

let expand_match
    ~(ext : Extension_name.t)
    ~loc
    (expr : expression)
    (cases : case list) =
  match ext with
  | Sat ->
      let cases = List.map (transform_case ~ext ~expr) cases in
      let fexpr = if_fexpr ~ext loc in
      let non_exhaustive_error =
        pexp_apply ~loc
          (pexp_ident ~loc (Located.mk ~loc (Lident "failwith")))
          [
            ( Nolabel,
              pexp_constant ~loc
                (Pconst_string
                   ("Non-exhaustive %sat pattern matching", loc, None)) );
          ]
      in
      List.fold_right
        (fun (lhs, rhs) acc ->
          pexp_apply ~loc fexpr
            [
              (Nolabel, lhs);
              (Labelled "then_branch", rhs);
              (Labelled "else_branch", to_thunk ~loc acc);
            ])
        cases non_exhaustive_error
  | Ent ->
      let cases =
        List.map
          (fun case ->
            let lhs, rhs = transform_case ~ext ~expr case in
            pexp_tuple ~loc:case.pc_lhs.ppat_loc [ lhs; rhs ])
          cases
      in
      let list_cases = elist ~loc cases in
      pexp_apply ~loc (match_fexpr ~ext loc) [ (Nolabel, list_cases) ]

let expand ~ext expr =
  let loc = { expr.pexp_loc with loc_ghost = true } in
  let expansion =
    match expr.pexp_desc with
    | Pexp_match (expr, cases) -> expand_match ~ext ~loc expr cases
    | Pexp_ifthenelse (expr, then_, else_) ->
        let else_ =
          match else_ with
          | Some else_ -> else_
          | None ->
              Location.raise_errorf ~loc "'if%%%s' must include an else branch"
                (Extension_name.to_string ext)
        in
        expand_if ~ext ~loc expr then_ else_
    | _ ->
        Location.raise_errorf ~loc "%%%s can only be used with 'if' and 'match'"
          (Extension_name.to_string ext)
  in
  {
    expansion with
    pexp_attributes = expr.pexp_attributes @ expansion.pexp_attributes;
  }
