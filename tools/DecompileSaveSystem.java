// Ghidra script to decompile save and load functions.
// @category Analysis

import java.io.File;
import java.io.PrintWriter;
import java.util.HashMap;
import java.util.Map;

import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionManager;

public class DecompileSaveSystem extends GhidraScript {
    @Override
    public void run() throws Exception {
        println("=== Decompiling Save/Load System ===");

        DecompInterface decomp = new DecompInterface();
        decomp.openProgram(currentProgram);

        File outDir = new File("C:/projects/puzzle_quest/docs/decompiled/save_system");
        outDir.mkdirs();

        FunctionManager fnManager = currentProgram.getFunctionManager();

        Map<String, Long> saveTargets = new HashMap<>();
        saveTargets.put("Save_FileHelper_44cb70", 0x0044cb70L);
        saveTargets.put("Save_CheckDamaged_44cbf0", 0x0044cbf0L);
        saveTargets.put("Save_DeleteHero_44cc80", 0x0044cc80L);
        saveTargets.put("Save_GetSavePath_44e7e0", 0x0044e7e0L);
        saveTargets.put("Save_HeroFile_44ea10", 0x0044ea10L);
        saveTargets.put("Hero_SaveToFile_4676f0", 0x004676f0L);
        saveTargets.put("Hero_LoadFromFile_468000", 0x00468000L);
        saveTargets.put("Hero_ReadHeader_468450", 0x00468450L);
        saveTargets.put("Save_EnumerateHeroes_46cd00", 0x0046cd00L);
        saveTargets.put("Network_PQHERO_Parse_4d8780", 0x004d8780L);
        saveTargets.put("File_Load_4d7cd0", 0x004d7cd0L);
        saveTargets.put("File_Save_4d76e0", 0x004d76e0L);

        for (Map.Entry<String, Long> entry : saveTargets.entrySet()) {
            Address a = currentAddress.getAddress(Long.toHexString(entry.getValue()));
            Function f = fnManager.getFunctionContaining(a);
            if (f == null) {
                f = fnManager.getFunctionAt(a);
            }
            if (f == null) {
                f = createFunction(a, entry.getKey());
            } else {
                f.setName(entry.getKey(), ghidra.program.model.symbol.SourceType.USER_DEFINED);
            }

            if (f != null) {
                DecompileResults res = decomp.decompileFunction(f, 60, monitor);
                if (res != null && res.decompileCompleted()) {
                    File outFile = new File(outDir, entry.getKey() + ".c");
                    PrintWriter pw = new PrintWriter(outFile);
                    pw.write(res.getDecompiledFunction().getC());
                    pw.close();
                    println("Decompiled " + entry.getKey() + " -> " + outFile.getName());
                } else {
                    println("Failed decompiling: " + entry.getKey());
                }
            } else {
                println("Could not resolve function for: " + entry.getKey());
            }
        }
        println("=== Save/Load System Decompilation Complete ===");
    }
}
