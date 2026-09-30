import pefile
import struct

def main():
    pe = pefile.PE("game/Puzzle Quest.exe")
    image_base = pe.OPTIONAL_HEADER.ImageBase

    sample_strings = [b"GET_GEM\x00", b"ADD_LIFE\x00", b"EVALUATE_BOARD\x00", b"DESTROY_GEM\x00", b"EXTRA_TURN\x00"]
    for s in sample_strings:
        name = s.decode("ascii", errors="ignore").strip("\x00")
        str_offset = pe.__data__.find(s)
        if str_offset == -1:
            print(f"String {name} not found")
            continue
        str_va = image_base + str_offset
        print(f"\nString '{name}' at VA: {hex(str_va)}")

        va_bytes = struct.pack("<I", str_va)
        ptr_offset = 0
        while True:
            idx = pe.__data__.find(va_bytes, ptr_offset)
            if idx == -1:
                break
            ref_va = image_base + idx
            sec = pe.get_section_by_rva(idx)
            sec_name = sec.Name.decode().strip("\x00") if sec else "unknown"
            print(f"  Referenced at VA: {hex(ref_va)} (section: {sec_name})")

            # Check if this looks like a struct luaL_Reg { const char *name; void *func; }
            # Or if it's referenced in code (.text)
            if sec_name in [".rdata", ".data"]:
                # Check adjacent dwords
                surrounding = pe.__data__[idx:idx+16]
                dwords = [hex(x) for x in struct.unpack("<" + "I"*(len(surrounding)//4), surrounding)]
                print(f"    Table entry candidate: {dwords}")
            elif sec_name == ".text":
                code_bytes = pe.__data__[max(0, idx-10):idx+15]
                print(f"    Code bytes: {code_bytes.hex()}")

            ptr_offset = idx + 1

if __name__ == "__main__":
    main()
