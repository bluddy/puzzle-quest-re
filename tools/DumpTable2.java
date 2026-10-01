// Dump little-endian int32 values from the binary, one address per line.
// @category Analysis

import java.io.File;
import java.io.PrintWriter;

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.mem.Memory;

public class DumpTable2 extends GhidraScript {

    @Override
    public void run() throws Exception {
        File out = new File("C:/projects/puzzle_quest/docs/decompiled/tables.txt");
        Memory mem = currentProgram.getMemory();
        int start = 0;
        while (start < getScriptArgs().length && !getScriptArgs()[start].startsWith("0x")) {
            start++;
        }
        try (PrintWriter pw = new PrintWriter(out)) {
            pw.println("# va        int32");
            for (int i = start; i < getScriptArgs().length; i += 2) {
                long va = Long.decode(getScriptArgs()[i]);
                int count = Integer.decode(getScriptArgs()[i + 1]);
                pw.println("=== base 0x" + Long.toHexString(va) + " ===");
                Address a = currentProgram.getAddressFactory().getDefaultAddressSpace().getAddress(va);
                for (int k = 0; k < count; k++) {
                    Address cur = a.add(k * 4);
                    pw.println("0x" + cur + "  " + mem.getInt(cur));
                }
            }
        }
        println("=== wrote " + out + " ===");
    }
}
