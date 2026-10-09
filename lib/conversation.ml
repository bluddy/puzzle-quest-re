(** Conversation data structures and logic.

    The game has 273 conversation scripts, each with a character name and
    sequential dialogue lines. The engine triggers conversations via
    [Lua_QUEST_CONVERSATION] with two string arguments (conversation ID
    and starting point). The text content is stored in the TextLibrary under
    tags like [Conv_Q0I2a_NAME1], [Conv_Q0I2a_0000], etc. *)

(** Helper to append to a list in a hashtable. *)
let hashtbl_append tbl key value =
  try
    let existing = Hashtbl.find tbl key in
    Hashtbl.replace tbl key (value :: existing)
  with Not_found ->
    Hashtbl.add tbl key [value]

(** A single line of dialogue. *)
type line = {
  speaker: string;     (** Character name, from the NAME tag *)
  text: string;        (** The dialogue text *)
}

(** A conversation script: character name + sequence of lines. *)
type t = {
  id: string;              (** e.g. "Q0I2a" *)
  speaker_name: string;    (** From the _NAME1 tag *)
  lines: line list;        (** Sequential dialogue, from _0000, _0001, etc. *)
}

(** Load all conversations from the text table. *)
let load_all : unit -> t list = fun () ->
  let table = Text_data.entries in
  let conv_map = Hashtbl.create 300 in
  let lines_map = Hashtbl.create 300 in
  let is_conv tag =
    String.length tag > 7 && String.sub tag 0 6 = "[Conv_"
    && tag.[String.length tag - 1] = ']'
  in
  let parse tag =
    (* tag = [Conv_<id>_<suffix>] *)
    let body = String.sub tag 6 (String.length tag - 7) in
    match String.index_opt body '_' with
    | None -> None
    | Some u ->
      Some (String.sub body 0 u,
            String.sub body (u + 1) (String.length body - u - 1))
  in
  List.iter (fun (tag, text) ->
    if is_conv tag then
      match parse tag with
      | Some (conv_id, "NAME1") -> Hashtbl.replace conv_map conv_id text
      | Some (conv_id, suffix) when String.length suffix > 0
                                    && suffix.[0] >= '0' && suffix.[0] <= '9' ->
          hashtbl_append lines_map conv_id (int_of_string suffix, text)
      | _ -> ())
    table;
  (* Build conversation records *)
  let rec build conv_ids acc =
    match conv_ids with
    | [] -> List.rev acc
    | conv_id :: rest ->
      let speaker = Hashtbl.find_opt conv_map conv_id in
      let lines = Hashtbl.find_opt lines_map conv_id in
      (match speaker, lines with
       | Some name, Some pairs ->
            let sorted = List.sort (fun (n1,_) (n2,_) -> n1 - n2) pairs in
            let lines = List.map (fun (_, t) -> { speaker = name; text = t }) sorted in
            build rest ({ id = conv_id; speaker_name = name; lines } :: acc)
       | _ -> build rest acc)
  in
  build (Hashtbl.fold (fun k _ acc -> k :: acc) conv_map []) []

(** Find a conversation by ID. *)
let find (convs: t list) (id: string) : t option =
  List.find_opt (fun c -> c.id = id) convs

(** Get the next line in a conversation, or [None] if at the end. *)
let next_line (c: t) (index: int) : line option =
  if index < List.length c.lines then Some (List.nth c.lines index) else None

(** Convert a conversation to a string for debugging. *)
let to_string (c: t) : string =
  Printf.sprintf "Conversation %s (%s): %d lines" c.id c.speaker_name (List.length c.lines)