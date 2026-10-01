// Find every function that references a given global/data address and decompile it.
// @category Analysis

import java.io.File;
import java.io.PrintWriter;
import java.util.HashSet;
import java.util.Set;

import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionManager;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.ReferenceIterator;

public class DecompileXrefs extends GhidraScript {

    @Override
    public void run() throws Exception {
        String targetHex = getScriptArgs()[0];   // e.g. 0x005828dc
        String outName = getScriptArgs()[1];   // output subdirectory name
        long minVa = 0x00401000L;
        long maxVa = 0x004F0000L;

        DecompInterface decomp = new DecompInterface();
        decomp.openProgram(currentProgram);

        File outDir = new File("C:/projects/puzzle_quest/docs/decompiled/" + outName);
        outDir.mkdirs();

        FunctionManager fm = currentProgram.getFunctionManager();
        Address target = currentProgram.getAddressFactory().getDefaultAddressSpace()
                .getAddress(Long.decode(targetHex));

        Set<Long> seen = new HashSet<>();
        int count = 0;
        ReferenceIterator it = currentProgram.getReferenceManager().getReferencesTo(target);
        while (it.hasNext()) {
            Reference ref = it.next();
            Address from = ref.getFromAddress();
            Function f = fm.getFunctionContaining(from);
            if (f == null) {
                continue;
            }
            long va = f.getEntryPoint().getOffset();
            if (va < minVa || va >= maxVa) {
                continue;
            }
            if (!seen.add(va)) {
                continue;
            }
            DecompileResults res = decomp.decompileFunction(f, 90, monitor);
            if (res != null && res.decompileCompleted()) {
                String n = f.getName().startsWith("FUN_")
                        ? "Sub_" + Long.toHexString(va) : f.getName();
                try (PrintWriter pw = new PrintWriter(new File(outDir, n + ".c"))) {
                    pw.write("// refs " + targetHex + " @ " + from + "\n");
                    pw.write(res.getDecompiledFunction().getC());
                }
                count++;
            }
        }
        println("=== xref decompile of " + targetHex + ": " + count + " functions ===");
    }
}
