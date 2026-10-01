// Ghidra script to export decompiled C code for all Lua bridge functions and their dependencies.
// @category Analysis

import java.io.File;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionManager;

public class ExportLuaFunctions extends GhidraScript {
    @Override
    public void run() throws Exception {
        println("Starting ExportLuaFunctions script...");

        DecompInterface decomp = new DecompInterface();
        decomp.openProgram(currentProgram);

        // Core functions we want to decompile first
        Map<String, Long> targetFunctions = new HashMap<>();
        targetFunctions.put("CBattleManager_EvaluateBoard", 0x00440C20L);
        targetFunctions.put("CBattleManager_GetSingleton", 0x0043F870L);
        targetFunctions.put("Lua_EVALUATE_BOARD", 0x0048D240L);
        targetFunctions.put("Lua_GET_GEM", 0x0048DE70L);
        targetFunctions.put("Lua_DESTROY_GEM", 0x0048D1A0L);
        targetFunctions.put("Lua_DELETE_GEM", 0x0048D110L);
        targetFunctions.put("Lua_EXTRA_TURN", 0x0048D270L);
        targetFunctions.put("Lua_ADD_LIFE", 0x004965A0L);
        targetFunctions.put("Lua_ADD_GOLD", 0x004975F0L);
        targetFunctions.put("Lua_ADD_MANA_EARTH", 0x00496780L);
        targetFunctions.put("Lua_ADD_MANA_FIRE", 0x00496870L);
        targetFunctions.put("Lua_ADD_MANA_WATER", 0x00496960L);
        targetFunctions.put("Lua_ADD_MANA_AIR", 0x00496690L);
        targetFunctions.put("Lua_GET_SKILL", 0x0048F190L);
        targetFunctions.put("Lua_RegistrationInit", 0x004976F0L);

        File outDir = new File("C:/projects/puzzle_quest/docs/decompiled");
        outDir.mkdirs();

        FunctionManager fnManager = currentProgram.getFunctionManager();

        for (Map.Entry<String, Long> entry : targetFunctions.entrySet()) {
            String name = entry.getKey();
            Address addr = currentProgram.getAddressFactory().getDefaultAddressSpace().getAddress(entry.getValue());
            Function func = fnManager.getFunctionAt(addr);
            if (func == null) {
                // Try creating function at address if not existing
                func = createFunction(addr, name);
            } else {
                func.setName(name, ghidra.program.model.symbol.SourceType.USER_DEFINED);
            }

            if (func != null) {
                DecompileResults res = decomp.decompileFunction(func, 60, monitor);
                if (res != null && res.decompileCompleted()) {
                    String cCode = res.getDecompiledFunction().getC();
                    File outFile = new File(outDir, name + ".c");
                    PrintWriter pw = new PrintWriter(outFile);
                    pw.write(cCode);
                    pw.close();
                    println("Decompiled " + name + " -> " + outFile.getAbsolutePath());
                } else {
                    println("Failed to decompile: " + name);
                }
            } else {
                println("Could not find or create function at: " + Long.toHexString(entry.getValue()));
            }
        }

        println("Export complete!");
    }
}
