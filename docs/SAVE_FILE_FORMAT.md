# Puzzle Quest: Save File Format (`.pqhero`)

## 1. File Structure Overview
A `.pqhero` file (stored in `%USERPROFILE%\Documents\Puzzle Quest\Saves\<HeroName>.pqhero`) consists of three distinct contiguous sections:

```
+-------------------------------------------------------------+
| 1. RGMH File Header (Fixed 8,232 bytes / 0x2028)            |
|    - Magic: "RGMH" (0x484D4752)                             |
|    - Version & Sizes                                        |
|    - Summary Text: Name, Class, Level, Gold, Battles        |
+-------------------------------------------------------------+
| 2. Embedded Hero Portrait / Thumbnail (PNG Image)           |
|    - Starts at offset 0x2028                                |
|    - Standard 256x256 PNG image file (\x89PNG\r\n\x1a\n)    |
|    - Length = PayloadSize from Header (approx. 100 KB)      |
+-------------------------------------------------------------+
| 3. Serialized & Encrypted Hero State                        |
|    - Follows immediately after the PNG image (IEND chunk)   |
|    - Encrypted via WET Engine crypto (WETSTD32.DLL)         |
|    - Key: "jhgsd&*(d9shgsf098aLKJ"                          |
|    - Contains skills, HP, XP, Mana, Gold, Spells, Quests    |
+-------------------------------------------------------------+
```

---

## 2. Header Specification (`RGMH`)
* **Offset `0x00` (4 bytes)**: `uint32_t magic` = `0x484D4752` (`"RGMH"`)
* **Offset `0x04` (4 bytes)**: `uint32_t version` = `1`
* **Offset `0x08` (4 bytes)**: `uint32_t header_size` = `8232` (`0x2028`)
* **Offset `0x0C` (4 bytes)**: `uint32_t flags` / reserved
* **Offset `0x10` (4 bytes)**: `uint32_t unknown`
* **Offset `0x14` (4 bytes)**: `uint32_t png_payload_size` (e.g. 104,684 bytes)
* **Offset `0x18` (16 bytes)**: 128-bit GUID / File hash check
* **Offset `0x28` (Variable UTF-16LE)**:
  * Application identifier: `L"Puzzle Quest\0"`
  * Hero Summary: `L"<HeroName> - <Class> (Level <N>)\0"`
  * Gold Summary: `L"<Gold> Gold\0"`
  * Record Summary: `L"Battles: <B>    Victories: <V>\0"`

---

## 3. Embedded PNG Preview
* Located at byte offset `0x2028` (8232).
* Standard valid PNG starting with header `89 50 4E 47 0D 0A 1A 0A`.
* Rendered by the engine at character creation / save time and displayed directly on the "Select Hero" menu carousel.

---

## 4. Encrypted Hero State & Serialization Layout

### Encryption Pipeline (`WETSTD32.DLL`)
The data block following the PNG is encrypted using the engine's proprietary triple-layer involution:
* **Key**: `L"jhgsd&*(d9shgsf098aLKJ"`
* **Save Order**:
  1. `EncryptTranspositionBlock` (Block byte-reversal with block size $((\text{sum} + \text{len}) \pmod{16}) + 2$)
  2. `EncryptSubstitutionBlock` (Prime-modulus pseudo-random XOR keystream)
  3. `EncryptXORBlock` (Standard rolling XOR)
* **Load Order**:
  1. `EncryptXORBlock`
  2. `EncryptSubstitutionBlock`
  3. `EncryptTranspositionBlock`

### Serialized Hero Binary Fields (from `0x0046D100`)
Once decrypted, the binary stream directly serializes:
1. `+0x00` (4 bytes): Character ID / flags
2. `+0x04` (28 bytes): The **7 Core Attributes** ($7 \times 4$ bytes):
   * `[0]` Earth Mastery
   * `[1]` Fire Mastery
   * `[2]` Water Mastery
   * `[3]` Air Mastery
   * `[4]` Battle
   * `[5]` Morale
   * `[6]` Cunning
3. `+0x20` (4 bytes): `m_maxLife` (Maximum HP)
4. `+0x24` (4 bytes): `m_level` (Hero Level 1–50)
5. `+0x28` (4 bytes): `m_currentXP` (Current Experience points)
6. `+0x2C` (4 bytes): `m_currentLife` (Current HP)
7. `+0x30` (16 bytes): Current Mana Pools ($4 \times 4$ bytes: Air, Earth, Fire, Water)
8. `+0x40` (4 bytes): Current City / Map Node Location (e.g. `CBAR`)
9. `+0x44` (2 bytes): Location sub-state
10. `+0x46` (4 bytes): `m_currentGold` (Player gold reserves)
11. Subsequent arrays:
    * Equipped items & inventory array
    * Learned spells & equipped spell list (up to 7)
    * Companions array
    * Captured monsters & mount levels
    * Captured cities & tribute collection timers
    * Quest flags & completed quest IDs
