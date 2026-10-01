// Decompile every function defined within an address range.
// @category Analysis

import java.io.File;
import java.io.PrintWriter;
import java.util.HashSet;
import java.util.Set;

import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.address.AddressSetView;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionIterator;
import ghidra.program.model.listing.FunctionManager;

public class DecompileRange extends GhidraScript {

    @Override
    public void run() throws Exception {
        long from = Long.decode(getScriptArgs()[0]);
        long to = Long.decode(getScriptArgs()[1]);
        String outName = getScriptArgs()[2];

        DecompInterface decomp = new DecompInterface();
        decomp.openProgram(currentProgram);

        File outDir = new File("C:/projects/puzzle_quest/docs/decompiled/" + outName);
        outDir.mkdirs();

        FunctionManager fm = currentProgram.getFunctionManager();
        Address a = currentProgram.getAddressFactory().getDefaultAddressSpace().getAddress(from);
        Address b = currentProgram.getAddressFactory().getDefaultAddressSpace().getAddress(to);

        int count = 0;
        Set<Long> seen = new HashSet<>();
        Address cur = a;
        while (cur.compareTo(b) <= 0) {
            Function f = fm.getFunctionContaining(cur);
            if (f != null && seen.add(f.getEntryPoint().getOffset())) {
                DecompileResults res = decomp.decompileFunction(f, 90, monitor);
                if (res != null && res.decompileCompleted()) {
                    String n = f.getName().startsWith("FUN_")
                            ? "Sub_" + Long.toHexString(f.getEntryPoint().getOffset()) : f.getName();
                    try (PrintWriter pw = new PrintWriter(new File(outDir, n + ".c"))) {
                        pw.write(res.getDecompiledFunction().getC());
                    }
                    count++;
                } else {
                    println("!! failed: " + f.getName());
                }
            }
            cur = cur.add(1);
        }
        println("=== decompiled " + count + " functions in range ===");
    }
}
