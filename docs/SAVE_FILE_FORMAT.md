# Puzzle Quest: Save File Format (`.pqhero`)

## 1. File Structure Overview
A `.pqhero` file (stored in `%USERPROFILE%\Documents\Puzzle Quest\Saves\<HeroName>.pqhero`) consists of three distinct contiguous sections:

```
+-------------------------------------------------------------+
| 1. RGMH File Header (Fixed 8,232 bytes / 0x2028)            |
|    - Magic: "RGMH" (0x484D4752)                             |
|    - Version: 1                                             |
|    - Header Size: 8,232 (0x2028)                            |
|    - Flags / reserved                                       |
|    - PNG Payload Size (e.g. 104,684 bytes)                  |
|    - 128-bit GUID                                           |
|    - Summary UTF-16LE strings (App name, Hero summary, etc.)|
+-------------------------------------------------------------+
| 2. Embedded Hero Portrait / Thumbnail (PNG Image)           |
|    - Starts at offset 0x2028                                |
|    - Length = PNG Payload Size from Header                  |
|    - Standard 256x256 RGBA PNG                              |
+-------------------------------------------------------------+
| 3. Serialized & Encrypted Hero State                        |
|    - Starts at offset: 0x2028 + png_payload_size            |
|    - First 4 bytes: uint32_t decrypted_crc (CRC-16/ARC)     |
|    - Next 4 bytes: uint32_t encrypted_crc (CRC-16/ARC)      |
|    - Remaining bytes: Encrypted hero binary payload         |
+-------------------------------------------------------------+
```

---

## 2. Encryption Pipeline & Key Discovery

The game engine utilizes the legacy `WETSTD32.DLL` involution cipher library.
Each transformation is an **involution** (self-inverting: $f(f(x)) = x$).

### The Key Bug
In the PC release executable (`Puzzle Quest.exe`), `Hero_SaveToFile` and `Hero_LoadFromFile` pass the key string literal `L"jhgsd&*(d9shgsf098aLKJ"` (UTF-16LE) to the standard C DLL functions expecting `const char*`.
Because x86 is little-endian, the first character `'j'` is encoded as `0x6A, 0x00`.
The null byte terminates the C-string immediately at length 1.
Therefore, **the effective encryption key for all Puzzle Quest PC saves is the single byte `b"j"` (`0x6A`)**.

### Cipher Algorithms
1. **Transposition (`_EncryptTranspositionBlock`)**:
   - `sum_key = sum(key_bytes) = 0x6A = 106`
   - `block_size = ((sum_key + key_len) % 16) + 2 = ((106 + 1) % 16) + 2 = 13`
   - Reverses bytes in contiguous blocks of size 13 (with the final chunk taking the remainder).
2. **Substitution (`_EncryptSubstitutionBlock`)**:
   - Prime modulus selected from 50 prime constants (`TABLE_SIZES`): `prime = TABLE_SIZES[sum_key % 50] = TABLE_SIZES[106 % 50] = TABLE_SIZES[6] = 1021`.
   - Rolling keystream: `acc = sum_key & 0xFF`; for each byte `i < prime`: `acc = (acc + key[i % key_len]) & 0xFF`, `sub_buf[i] = key[i % key_len] ^ acc`.
   - Data is XORed with `sub_buf[i % prime]`.
3. **XOR (`_EncryptXORBlock`)**:
   - Rolling XOR of data with `key[i % key_len]`. With `key = b"j"`, each byte is XORed with `0x6A`.

### Cipher Pipeline Order
- **Save (Encryption)**:
  1. Calculate `decrypted_crc = CRCBlock(payload)`
  2. `_EncryptXORBlock(payload, key)`
  3. `_EncryptSubstitutionBlock(payload, key)`
  4. `_EncryptTranspositionBlock(payload, key)`
  5. Calculate `encrypted_crc = CRCBlock(payload)`
- **Load (Decryption)**:
  1. Verify `CRCBlock(encrypted_payload) == encrypted_crc`
  2. `_EncryptTranspositionBlock(payload, key)`
  3. `_EncryptSubstitutionBlock(payload, key)`
  4. `_EncryptXORBlock(payload, key)`
  5. Verify `CRCBlock(payload) == decrypted_crc`

### CRC Algorithm (`_CRCBlock`)
Standard CRC-16 (IBM / ARC table, polynomial `0xA001`, initial value `0x0000`).

---

## 3. Decrypted Hero State Binary Layout

Once decrypted, the payload follows this exact sequential layout:

1. **Hero Name**:
   - `uint16_t name_length` (character count)
   - `wchar_t name[name_length]` (UTF-16LE, no trailing null)
2. **Portrait Path**:
   - `uint16_t portrait_length` (character count)
   - `wchar_t portrait[portrait_length]` (e.g. `Assets\Portraits\Portrait_PC_Druid0.png`)
   - `uint16_t null_terminator` (`0x0000`)
3. **Core Attributes (7 × uint32_t)**:
   - `[0]` Earth Mastery
   - `[1]` Fire Mastery
   - `[2]` Water Mastery
   - `[3]` Air Mastery
   - `[4]` Battle
   - `[5]` Morale
   - `[6]` Cunning
4. **Hero Progression (4 × uint32_t)**:
   - `m_maxLife` (Max HP)
   - `m_level` (Hero Level 1–50)
   - `m_currentXP` (Experience Points)
   - `m_currentLife` (Current HP)
5. **Mana Reserves (4 × uint32_t)**:
   - Air Mana
   - Earth Mana
   - Fire Mana
   - Water Mana
6. **Class ID**:
   - 4 ASCII bytes (e.g. `PDRU` = Druid, `PWIZ` = Wizard, `PKNI` = Knight, `PWAR` = Warrior)
7. **Flags & Gold**:
   - `uint16_t flags`
   - `uint32_t gold` (Current gold reserves)
8. **Location & State**:
   - `uint32_t location_id`
   - `uint32_t location_sub`
9. **Spells Inventory**:
   - `uint32_t spell_count`
   - Array of `spell_count` entries (8 bytes each):
     - `char code[4]` (e.g. `SGEM`, `SCHA`, `SENT`, `SFBO`)
     - `uint8_t learned` (1 if available to equip)
     - `uint8_t equipped` (1 if currently equipped on battle bar)
     - `uint8_t slot` (equipped index 1..7)
     - `uint8_t pad`
10. **Items / Equipment, Companions, Captives, Quests**:
    - Remaining serialized structures follow in standard array format.
