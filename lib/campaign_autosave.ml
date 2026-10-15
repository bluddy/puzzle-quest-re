(** Auto-save: the original's dirty-flag + pump, wired to the port's own
    JSON round-trip.

    The original keeps a dirty byte on the hero (hero+0xbc, cleared when a
    save succeeds at FUN_0046fb4a); state-changing events - the calendar
    advance, battle records, quest completion, city rebellion, the hero load
    itself - set it, and a per-frame pump (FUN_0044d53c) shows the
    [MSG_AUTOSAVE] box and writes every dirty hero to
    My Documents\Puzzle Quest\Saves\<HeroName>.pqhero (the key beside the
    path builder is the format's encryption secret, now xref-pinned at
    0x52246c - see docs/SAVE_FILE_FORMAT.md). The port keeps the architecture
    and swaps the medium: [Campaign.dirty] is the flag (set by Campaign's own
    mutators, mirroring where the original's writes sat), [pump] is what the
    map front calls every frame, and the file is the campaign_save JSON in
    the working directory - the original's My Documents path needs the
    Shell32 folder call the port does not port, and its .pqhero binary is
    [Save_file]'s separate surface (the port round-trips its own state, not
    the original's encrypted payload).

    What the save does not model: a mid-journey resume. The hero lands at
    their last location (player.current_city) and the travel_state slot the
    format carries is written as 0 - the original field's travel encoding is
    unpinned, and the front rebuilds a standing hero on load. *)
let filename = "pq_save.json"

(** Write the hero out now and clear the flag. Returns true when a file was
    written. *)
let save (player : Campaign.player) : bool =
  let location =
    match player.Campaign.current_city with Some c -> c | None -> ""
  in
  let data =
    Campaign_save.create_save_data player player.Campaign.active_quests
      location 0
  in
  Campaign_save.save_to_file filename data;
  Campaign.dirty := false;
  true

(** The Continue entry: load the file if it is there, restore the live map
    tables through [Campaign_save.apply_save] (visibility and the ruin
    registry come back with the player), and clear the flag - a load is not
    a change worth rewriting the file we just read. *)
let load () :
    (Campaign.player * (string * int) list * string list * string list
    * string * int)
    option =
  if not (Sys.file_exists filename) then None
  else
    try
      let s = Campaign_save.load_from_file filename in
      let r = Campaign_save.apply_save s in
      Campaign.dirty := false;
      Some r
    with _ -> None

(** The pump: drain the flag by writing the current hero. The map front calls
    this every frame; events between frames coalesce into one write, the way
    the original's queue did. Returns true when this frame saved. *)
let pump (player : Campaign.player) : bool =
  if !Campaign.dirty then save player else false
