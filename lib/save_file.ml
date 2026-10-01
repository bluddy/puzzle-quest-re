(** Save file parser and serializer for Puzzle Quest (.pqhero)
    Format specification based on clean-room reverse engineering.
*)

type header = {
  magic : string;
  version : int;
  header_size : int;
  flags : int;
  png_size : int;
  guid : string;
  app_name : string;
  hero_summary : string;
  gold_summary : string;
  record_summary : string;
}

type attributes = {
  earth : int;
  fire : int;
  water : int;
  air : int;
  battle : int;
  morale : int;
  cunning : int;
}

type mana_pools = {
  air : int;
  earth : int;
  fire : int;
  water : int;
}

type spell_entry = {
  code : string;
  learned : bool;
  equipped : bool;
  level_req : int;
}

type hero_state = {
  name : string;
  portrait_path : string;
  attributes : attributes;
  max_life : int;
  level : int;
  xp : int;
  cur_life : int;
  mana : mana_pools;
  class_id : string;
  flags : int;
  gold : int;
  location_id : int;
  location_sub : int;
  spells : spell_entry list;
  raw_payload : bytes;
}

type save_file = {
  header : header;
  png_image : bytes;
  decrypted_crc : int;
  encrypted_crc : int;
  hero : hero_state;
}

(* --- Binary Decoding Helpers --- *)

let read_uint16 (buf : bytes) (pos : int) : int =
  let b0 = Char.code (Bytes.get buf pos) in
  let b1 = Char.code (Bytes.get buf (pos + 1)) in
  b0 lor (b1 lsl 8)

let read_uint32 (buf : bytes) (pos : int) : int =
  let b0 = Char.code (Bytes.get buf pos) in
  let b1 = Char.code (Bytes.get buf (pos + 1)) in
  let b2 = Char.code (Bytes.get buf (pos + 2)) in
  let b3 = Char.code (Bytes.get buf (pos + 3)) in
  b0 lor (b1 lsl 8) lor (b2 lsl 16) lor (b3 lsl 24)

let decode_utf16le (buf : bytes) (offset : int) (char_count : int) : string =
  let b = Buffer.create char_count in
  for i = 0 to char_count - 1 do
    let lo = Char.code (Bytes.get buf (offset + i * 2)) in
    let hi = Char.code (Bytes.get buf (offset + i * 2 + 1)) in
    let codepoint = lo lor (hi lsl 8) in
    if codepoint < 128 then
      Buffer.add_char b (Char.chr codepoint)
    else
      Buffer.add_char b '?'
  done;
  Buffer.contents b

let read_utf16le_null_term (buf : bytes) (offset : int) (max_bytes : int) : string * int =
  let chars = ref [] in
  let pos = ref offset in
  let limit = offset + max_bytes in
  let found = ref false in
  while !pos + 1 < limit && not !found do
    let lo = Char.code (Bytes.get buf !pos) in
    let hi = Char.code (Bytes.get buf (!pos + 1)) in
    let code = lo lor (hi lsl 8) in
    pos := !pos + 2;
    if code = 0 then found := true
    else chars := (if code < 128 then Char.chr code else '?') :: !chars
  done;
  (String.of_seq (List.to_seq (List.rev !chars)), !pos)

(* --- Parsing Logic --- *)

let parse_header (raw : bytes) : header =
  let magic = String.sub (Bytes.to_string raw) 0 4 in
  if magic <> "RGMH" then
    failwith (Printf.sprintf "Invalid save magic: %s (expected RGMH)" magic);
  let version = read_uint32 raw 4 in
  let header_size = read_uint32 raw 8 in
  let flags = read_uint32 raw 12 in
  let png_size = read_uint32 raw 0x14 in
  let guid =
    let b = Buffer.create 32 in
    for i = 0x18 to 0x27 do
      Buffer.add_string b (Printf.sprintf "%02x" (Char.code (Bytes.get raw i)))
    done;
    Buffer.contents b
  in
  let app_name, pos1 = read_utf16le_null_term raw 0x28 256 in
  let hero_summary, pos2 = read_utf16le_null_term raw pos1 256 in
  let gold_summary, pos3 = read_utf16le_null_term raw pos2 256 in
  let record_summary, _ = read_utf16le_null_term raw pos3 256 in
  {
    magic;
    version;
    header_size;
    flags;
    png_size;
    guid;
    app_name;
    hero_summary;
    gold_summary;
    record_summary;
  }

let parse_hero_payload (payload : bytes) : hero_state =
  let pos = ref 0 in
  let name_len = read_uint16 payload !pos in
  pos := !pos + 2;
  let name = decode_utf16le payload !pos name_len in
  pos := !pos + (name_len * 2);

  let portrait_len = read_uint16 payload !pos in
  pos := !pos + 2;
  let portrait_path = decode_utf16le payload !pos portrait_len in
  pos := !pos + (portrait_len * 2);

  (* Skip 4-byte padding after portrait *)
  pos := !pos + 4;

  let earth = read_uint32 payload !pos in
  pos := !pos + 4;
  let fire = read_uint32 payload !pos in
  pos := !pos + 4;
  let water = read_uint32 payload !pos in
  pos := !pos + 4;
  let air = read_uint32 payload !pos in
  pos := !pos + 4;
  let battle = read_uint32 payload !pos in
  pos := !pos + 4;
  let morale = read_uint32 payload !pos in
  pos := !pos + 4;
  let cunning = read_uint32 payload !pos in
  pos := !pos + 4;
  let attributes = { earth; fire; water; air; battle; morale; cunning } in

  let max_life = read_uint32 payload !pos in
  pos := !pos + 4;
  let level = read_uint32 payload !pos in
  pos := !pos + 4;
  let xp = read_uint32 payload !pos in
  pos := !pos + 4;
  let cur_life = read_uint32 payload !pos in
  pos := !pos + 4;

  let m_air = read_uint32 payload !pos in
  pos := !pos + 4;
  let m_earth = read_uint32 payload !pos in
  pos := !pos + 4;
  let m_fire = read_uint32 payload !pos in
  pos := !pos + 4;
  let m_water = read_uint32 payload !pos in
  pos := !pos + 4;
  let mana = { air = m_air; earth = m_earth; fire = m_fire; water = m_water } in

  let class_id = String.sub (Bytes.to_string payload) !pos 4 in
  pos := !pos + 4;

  let flags = read_uint16 payload !pos in
  pos := !pos + 2;

  let gold = read_uint32 payload !pos in
  pos := !pos + 4;

  let location_id = read_uint32 payload !pos in
  pos := !pos + 4;
  let location_sub = read_uint32 payload !pos in
  pos := !pos + 4;

  let spell_count = read_uint32 payload !pos in
  pos := !pos + 4;

  let spells = ref [] in
  for _ = 0 to spell_count - 1 do
    let code = String.sub (Bytes.to_string payload) !pos 4 in
    let learned = Char.code (Bytes.get payload (!pos + 4)) <> 0 in
    let equipped = Char.code (Bytes.get payload (!pos + 5)) <> 0 in
    let level_req = Char.code (Bytes.get payload (!pos + 6)) in
    pos := !pos + 12;
    spells := { code; learned; equipped; level_req } :: !spells
  done;

  {
    name;
    portrait_path;
    attributes;
    max_life;
    level;
    xp;
    cur_life;
    mana;
    class_id;
    flags;
    gold;
    location_id;
    location_sub;
    spells = List.rev !spells;
    raw_payload = Bytes.copy payload;
  }

let load_save_file (filename : string) : save_file =
  let ic = open_in_bin filename in
  let len = in_channel_length ic in
  let raw = Bytes.create len in
  really_input ic raw 0 len;
  close_in ic;

  let header = parse_header raw in
  let png_start = header.header_size in
  let png_image = Bytes.sub raw png_start header.png_size in

  let payload_meta_start = png_start + header.png_size in
  let decrypted_crc = read_uint32 raw payload_meta_start in
  let encrypted_crc = read_uint32 raw (payload_meta_start + 4) in

  let encrypted_payload =
    Bytes.sub raw (payload_meta_start + 8) (len - payload_meta_start - 8)
  in

  (* Verify encrypted CRC *)
  let calc_enc_crc = Crypto.crc16 encrypted_payload in
  if calc_enc_crc <> encrypted_crc then
    failwith
      (Printf.sprintf "Encrypted CRC mismatch: got 0x%04x, expected 0x%04x"
         calc_enc_crc encrypted_crc);

  (* Decrypt payload *)
  let decrypted_payload = Bytes.copy encrypted_payload in
  Crypto.decrypt_payload decrypted_payload;

  (* Verify decrypted CRC *)
  let calc_dec_crc = Crypto.crc16 decrypted_payload in
  if calc_dec_crc <> decrypted_crc then
    failwith
      (Printf.sprintf "Decrypted CRC mismatch: got 0x%04x, expected 0x%04x"
         calc_dec_crc decrypted_crc);

  let hero = parse_hero_payload decrypted_payload in
  { header; png_image; decrypted_crc; encrypted_crc; hero }
