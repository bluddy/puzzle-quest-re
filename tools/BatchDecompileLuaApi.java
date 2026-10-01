// Ghidra script to batch-decompile all 191 Lua C-API functions and their direct callees from JSON map.
// @category Analysis

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.PrintWriter;
import java.util.HashSet;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionManager;

public class BatchDecompileLuaApi extends GhidraScript {
    @Override
    public void run() throws Exception {
        println("=== Starting BatchDecompileLuaApi (from JSON) ===");

        File jsonFile = new File("C:/projects/puzzle_quest/tools/lua_bindings.json");
        if (!jsonFile.exists()) {
            println("Error: tools/lua_bindings.json not found!");
            return;
        }

        DecompInterface decomp = new DecompInterface();
        decomp.openProgram(currentProgram);

        File outDir = new File("C:/projects/puzzle_quest/docs/decompiled");
        outDir.mkdirs();

        FunctionManager fnManager = currentProgram.getFunctionManager();
        Set<Long> decompiledAddresses = new HashSet<>();

        // Parse JSON entries using regex
        BufferedReader reader = new BufferedReader(new FileReader(jsonFile));
        String line;
        String curName = null;
        Long curVA = null;

        Pattern namePat = Pattern.compile("\"name\":\\s*\"([^\"]+)\"");
        Pattern vaPat = Pattern.compile("\"va\":\\s*\"(0x[0-9a-fA-F]+)\"");

        int count = 0;
        while ((line = reader.readLine()) != null) {
            Matcher mName = namePat.matcher(line);
            if (mName.find()) {
                curName = mName.group(1);
            }
            Matcher mVa = vaPat.matcher(line);
            if (mVa.find()) {
                curVA = Long.decode(mVa.group(1));
            }

            if (curName != null && curVA != null) {
                Address funcAddr = currentProgram.getAddressFactory().getDefaultAddressSpace().getAddress(curVA);
                Function f = fnManager.getFunctionAt(funcAddr);
                if (f == null) {
                    f = createFunction(funcAddr, "Lua_" + curName);
                } else {
                    f.setName("Lua_" + curName, ghidra.program.model.symbol.SourceType.USER_DEFINED);
                }

                if (f != null && !decompiledAddresses.contains(curVA)) {
                    decompileAndSave(decomp, f, new File(outDir, "Lua_" + curName + ".c"));
                    decompiledAddresses.add(curVA);
                    count++;

                    // Collect called engine functions inside this Lua wrapper
                    Set<Function> callees = f.getCalledFunctions(monitor);
                    for (Function callee : callees) {
                        long cAddr = callee.getEntryPoint().getOffset();
                        // Only decompile game engine functions (< 0x004F0000)
                        if (cAddr >= 0x00401000L && cAddr < 0x004F0000L && !decompiledAddresses.contains(cAddr)) {
                            String cName = callee.getName();
                            if (cName.startsWith("FUN_")) {
                                cName = "Engine_" + curName + "_" + Long.toHexString(cAddr);
                                callee.setName(cName, ghidra.program.model.symbol.SourceType.USER_DEFINED);
                            }
                            decompileAndSave(decomp, callee, new File(outDir, cName + ".c"));
                            decompiledAddresses.add(cAddr);
                        }
                    }
                }

                curName = null;
                curVA = null;
            }
        }
        reader.close();

        println("Batch decompilation finished! Successfully exported " + count + " Lua API functions and " + (decompiledAddresses.size() - count) + " engine callee functions.");
    }

    private void decompileAndSave(DecompInterface decomp, Function f, File outFile) {
        try {
            DecompileResults res = decomp.decompileFunction(f, 60, monitor);
            if (res != null && res.decompileCompleted()) {
                String c = res.getDecompiledFunction().getC();
                PrintWriter pw = new PrintWriter(outFile);
                pw.write(c);
                pw.close();
            }
        } catch (Exception e) {
            println("Error decompiling " + f.getName() + ": " + e.getMessage());
        }
    }
}
