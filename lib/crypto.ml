(** WETSTD32 Engine Involution Crypto Implementation
    Puzzle Quest: Challenge of the Warlords (2007)
    
    The engine uses a 3-layer involution cipher:
    - XOR block encryption
    - Substitution block encryption (rolling prime keystream)
    - Transposition block encryption (in-place chunk reversal)
    
    Due to a wide-string passing bug in Puzzle Quest.exe, the key
    "jhgsd&*(d9shgsf098aLKJ" as UTF-16LE produces a single-byte
    effective key 'j' (0x6A).
*)

let table_sizes = [|
  1009; 1999; 1013; 1997; 1019; 1993; 1021; 1987; 1031; 1979;
  1033; 1973; 1039; 1951; 1049; 1949; 1051; 1933; 1061; 1931;
  1063; 1913; 1069; 1907; 1087; 1901; 1091; 1889; 1093; 1879;
  1097; 1877; 1103; 1873; 1109; 1871; 1117; 1867; 1123; 1861;
  1129; 1847; 1151; 1831; 1153; 1823; 1163; 1813; 1171; 1803
|]

(** CRC-16 (IBM / ARC, polynomial 0xA001) lookup table *)
let crc_table =
  let tbl = Array.make 256 0 in
  for i = 0 to 255 do
    let c = ref i in
    for _ = 0 to 7 do
      if (!c land 1) <> 0 then
        c := (!c lsr 1) lxor 0xA001
      else
        c := !c lsr 1
    done;
    tbl.(i) <- !c
  done;
  tbl

(** Calculate CRC-16 over bytes buffer *)
let crc16 (data : bytes) : int =
  let c = ref 0 in
  for i = 0 to Bytes.length data - 1 do
    let b = Char.code (Bytes.get data i) in
    let idx = (b lxor !c) land 0xFF in
    c := crc_table.(idx) lxor (!c lsr 8)
  done;
  !c

(** Default encryption key used by Puzzle Quest PC release *)
let default_key = "j"

(** 1. Transposition Block: reverses bytes in contiguous chunks *)
let encrypt_transposition (data : bytes) (key : string) : unit =
  let klen = String.length key in
  if klen = 0 then ()
  else
    let sum_key = ref 0 in
    for i = 0 to klen - 1 do
      sum_key := !sum_key + Char.code (String.get key i)
    done;
    let block_size = ((!sum_key + klen) mod 16) + 2 in
    let total_len = Bytes.length data in
    let offset = ref 0 in
    while !offset < total_len do
      let curr_len = min block_size (total_len - !offset) in
      let i = ref 0 in
      let j = ref (curr_len - 1) in
      while !i < !j do
        let tmp = Bytes.get data (!offset + !i) in
        Bytes.set data (!offset + !i) (Bytes.get data (!offset + !j));
        Bytes.set data (!offset + !j) tmp;
        incr i;
        decr j
      done;
      offset := !offset + curr_len
    done

(** 2. Substitution Block: generates pseudo-random prime keystream and XORs *)
let encrypt_substitution (data : bytes) (key : string) : unit =
  let klen = String.length key in
  if klen = 0 then ()
  else
    let sum_key = ref 0 in
    for i = 0 to klen - 1 do
      sum_key := !sum_key + Char.code (String.get key i)
    done;
    let prime = table_sizes.(!sum_key mod 50) in
    let sub_buf = Bytes.create prime in
    let acc = ref (!sum_key land 0xFF) in
    for i = 0 to prime - 1 do
      let k = Char.code (String.get key (i mod klen)) in
      acc := (!acc + k) land 0xFF;
      Bytes.set sub_buf i (Char.chr (k lxor !acc))
    done;
    let total_len = Bytes.length data in
    for i = 0 to total_len - 1 do
      let b = Char.code (Bytes.get data i) in
      let s = Char.code (Bytes.get sub_buf (i mod prime)) in
      Bytes.set data i (Char.chr (b lxor s))
    done

(** 3. XOR Block: standard rolling XOR with key *)
let encrypt_xor (data : bytes) (key : string) : unit =
  let klen = String.length key in
  if klen = 0 then ()
  else
    let total_len = Bytes.length data in
    for i = 0 to total_len - 1 do
      let b = Char.code (Bytes.get data i) in
      let k = Char.code (String.get key (i mod klen)) in
      Bytes.set data i (Char.chr (b lxor k))
    done

(** Decrypt payload:
    Order: Transposition -> Substitution -> XOR *)
let decrypt_payload ?(key = default_key) (data : bytes) : unit =
  encrypt_transposition data key;
  encrypt_substitution data key;
  encrypt_xor data key

(** Encrypt payload:
    Order: XOR -> Substitution -> Transposition *)
let encrypt_payload ?(key = default_key) (data : bytes) : unit =
  encrypt_xor data key;
  encrypt_substitution data key;
  encrypt_transposition data key
