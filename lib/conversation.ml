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

(** Find the next underscore after position [pos]. *)
let find_underscore_after s pos =
  let len = String.length s in
  let rec loop i =
    if i >= len then len
    else if s.[i] = '_' then i
    else loop (i + 1)
  in
  if pos >= String.length s then String.length s else loop pos

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
  (* First pass: collect character names *)
  List.iter (fun (tag, text) ->
    if String.length tag > 10 && String.sub tag 0 9 = "[Conv_" then begin
      let underscore_pos = find_underscore_after tag 5 in
      let conv_id = String.sub tag 5 (find_underscore_after tag 5 - 5) in
      let suffix = String.sub tag (find_underscore_after tag (underscore_pos + 1)) (String.length tag - find_underscore_after tag 5 - 1) in
      if suffix = "NAME1" then Hashtbl.replace conv_map conv_id text
      else ()
    end)
    table;
  let lines_map = Hashtbl.create 300 in
  List.iter (fun (tag, text) ->
    if String.length tag > 9 && String.sub tag 0 9 = "[Conv_" then begin
      let underscore_pos = find_underscore_after tag 5 in
      let conv_id = String.sub tag 5 (underscore_pos - 5) in
      let suffix = String.sub tag (find_underscore_after tag (underscore_pos + 1)) (String.length tag - underscore_pos - 1) in
      if String.length suffix > 0 && suffix.[0] >= '0' && suffix.[0] <= '9' then begin
        let line_num = int_of_string suffix in
        hashtbl_append lines_map conv_id (line_num, text)
      end
    end)
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