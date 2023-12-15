module Binary = struct
  type t =
    | And
    | Ashr
    | Bitand
    | Bitor
    | Bitnand
    | Bitxor
    | Div
    | Equal
    | Ge
    | Gt
    | IeeeFloatEqual
    | IeeeFloatNotequal
    | Implies
    | Le
    | Lshr
    | Lt
    | Minus
    | Mod
    | Mult
    | Notequal
    | Or
    | OverflowResultMinus
    | OverflowResultMult
    | OverflowResultPlus
    | OverflowMinus
    | OverflowMult
    | OverflowPlus
    | Plus
    | ROk
    | Rol
    | Ror
    | Shl
    | Xor
  [@@deriving show { with_path = false }]

  let pp_display fmt t =
    let f = Fmt.pf fmt in
    match t with
    | And -> f "&&"
    | Ashr -> f ">>"
    | Bitand -> f "&"
    | Bitor -> f "|"
    | Bitnand -> f "~&"
    | Bitxor -> f "^"
    | Div -> f "/"
    | Equal -> f "=="
    | Ge -> f ">="
    | Gt -> f ">"
    | Le -> f "<="
    | Lshr -> f ">>"
    | Lt -> f "<"
    | Minus -> f "-"
    | Mod -> f "%%"
    | Mult -> f "*"
    | Notequal -> f "!="
    | Or -> f "||"
    | Plus -> f "+"
    | Shl -> f "<<"
    | Xor -> f "^"
    | _ -> Fmt.pf fmt "%a" pp t
end

module Self = struct
  type t = Postdecrement | Postincrement | Predecrement | Preincrement
  [@@deriving show { with_path = false }]
end

module Unary = struct
  type t =
    | Bitnot  (**  `~self` *)
    | BitReverse  (**  `__builtin_bitreverse<n>(self)` *)
    | Bswap  (**  `__builtin_bswap<n>(self)` *)
    | IsDynamicObject  (**  `__CPROVER_DYNAMIC_OBJECT(self)` *)
    | IsFinite  (**  `isfinite(self)` *)
    | Not  (**  `!self` *)
    | ObjectSize  (**  `__CPROVER_OBJECT_SIZE(self)` *)
    | PointerObject  (**  `__CPROVER_POINTER_OBJECT(self)` *)
    | PointerOffset  (**  `__CPROVER_POINTER_OFFSET(self)` *)
    | Popcount  (**  `__builtin_p opcount(self)` *)
    | CountTrailingZeros of { allow_zero : bool }
        (**  `__builtin_cttz(self)` *)
    | CountLeadingZeros of { allow_zero : bool }  (**  `__builtin_ctlz(self)` *)
    | UnaryMinus  (**  `-self` *)
  [@@deriving show { with_path = false }]

  let pp_display fmt t =
    let f = Fmt.pf fmt in
    match t with
    | Bitnot -> f "~"
    | Not -> f "!"
    | UnaryMinus -> f "-"
    | _ -> Fmt.pf fmt "%a" pp t
end
