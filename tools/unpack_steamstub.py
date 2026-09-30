#!/usr/bin/env python3
"""
Unpacker for SteamStub Variant 2.0 (x86) specifically tailored for Puzzle Quest: Challenge of the Warlords.
Restores the decrypted .text section and restores the Original Entry Point (OEP).
"""

import sys
import struct
import pefile

def steam_xor(data: bytes, key: int = 0) -> bytes:
    out = bytearray(data)
    offset = 0
    if key == 0:
        offset = 4
        key = struct.unpack("<I", data[:4])[0]
    for i in range(offset, len(data), 4):
        val = struct.unpack("<I", data[i:i+4])[0]
        dec = val ^ key
        key = val
        out[i:i+4] = struct.pack("<I", dec)
    return bytes(out)

def unpack(input_path: str, output_path: str):
    print(f"Reading {input_path}...")
    pe = pefile.PE(input_path)
    image_base = pe.OPTIONAL_HEADER.ImageBase
    ep_rva = pe.OPTIONAL_HEADER.AddressOfEntryPoint
    ep_offset = pe.get_offset_from_rva(ep_rva)

    magic = struct.unpack("<I", pe.__data__[ep_offset-4:ep_offset])[0]
    if magic != 0xC0DEC0DE:
        print(f"Error: Magic 0xC0DEC0DE not found at ep-4 (found {hex(magic)})")
        return False

    # Extract structOffset and structSize from the entry point instructions:
    # 53 51 52 56 57 55 8B EC 81 EC 00 10 00 00 BE <struct_va> B9 <count> ...
    # struct_va at ep_offset + 15
    struct_va = struct.unpack("<I", pe.__data__[ep_offset+15:ep_offset+19])[0]
    count = struct.unpack("<I", pe.__data__[ep_offset+20:ep_offset+24])[0]
    struct_size = count * 4
    struct_rva = struct_va - image_base
    struct_offset = pe.get_offset_from_rva(struct_rva)

    print(f"SteamStub DRM Header at VA: {hex(struct_va)} (size: {struct_size} bytes)")
    raw_header = pe.__data__[struct_offset:struct_offset+struct_size]
    dec_header = steam_xor(raw_header)

    # SteamStub32Var20_884_Header
    # offset 40 (0x28): OEP
    # offset 44 (0x2C): CodeSectionVirtualAddress
    # offset 48 (0x30): CodeSectionSize
    # offset 52 (0x34): CodeSectionXorKey
    # offset 56 (0x38): SteamAppId
    oep_va = struct.unpack("<I", dec_header[0x2C:0x30])[0] # wait, let's verify offset
    fields = struct.unpack("<16I", dec_header[:64])
    oep_va = fields[11]
    code_va = fields[12]
    code_size = fields[13]
    code_xor_key = fields[14]
    app_id = fields[15]

    print(f"  AppID: {app_id}")
    print(f"  OEP VA: {hex(oep_va)} (RVA: {hex(oep_va - image_base)})")
    print(f"  Code VA: {hex(code_va)}, Size: {hex(code_size)}")
    print(f"  Code XOR Key: {hex(code_xor_key)}")

    # Locate the code section (.text)
    code_rva = code_va - image_base
    code_sec = pe.get_section_by_rva(code_rva)
    if not code_sec:
        print("Error: Could not locate code section!")
        return False

    code_offset = code_sec.PointerToRawData
    code_data = bytearray(pe.__data__[code_offset:code_offset+code_size])

    # Decrypt code section
    key = code_xor_key
    for i in range(0, code_size, 4):
        val = struct.unpack("<I", code_data[i:i+4])[0]
        dec = val ^ key
        key = val
        code_data[i:i+4] = struct.pack("<I", dec)

    print(f"Successfully decrypted {code_size} bytes of code.")

    # Reconstruct the file bytes
    file_bytes = bytearray(pe.__data__)

    # Write decrypted code back into .text
    file_bytes[code_offset:code_offset+code_size] = code_data

    # Update OEP in OptionalHeader
    # Offset of AddressOfEntryPoint in OptionalHeader is PE_header_offset + 4 + 20 + 16 = 40 (0x28) into OptionalHeader
    pe_header_offset = pe.DOS_HEADER.e_lfanew
    opt_header_offset = pe_header_offset + 4 + 20
    entry_point_offset = opt_header_offset + 16
    new_oep_rva = oep_va - image_base
    file_bytes[entry_point_offset:entry_point_offset+4] = struct.pack("<I", new_oep_rva)

    print(f"Updated AddressOfEntryPoint to {hex(new_oep_rva)}")

    with open(output_path, "wb") as f:
        f.write(file_bytes)

    # Reopen with pefile to verify and recompute checksum
    pe_unpacked = pefile.PE(output_path)
    pe_unpacked.OPTIONAL_HEADER.CheckSum = pe_unpacked.generate_checksum()
    pe_unpacked.write(output_path)
    pe_unpacked.close()

    print(f"Saved unpacked binary to: {output_path}")
    return True

if __name__ == "__main__":
    src = "game/Puzzle Quest.exe"
    dst = "game/Puzzle Quest.unpacked.exe"
    if len(sys.argv) > 1:
        src = sys.argv[1]
    if len(sys.argv) > 2:
        dst = sys.argv[2]
    unpack(src, dst)
