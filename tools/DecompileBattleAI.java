// Ghidra script to decompile the battle AI heuristic chain (EVALUATE_BOARD).
// @category Analysis

import java.io.File;
import java.io.PrintWriter;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;

import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionManager;

public class DecompileBattleAI extends GhidraScript {

    private DecompInterface decomp;
    private File outDir;
    private Set<Long> done = new HashSet<>();

    @Override
    public void run() throws Exception {
        decomp = new DecompInterface();
        decomp.openProgram(currentProgram);

        outDir = new File("C:/projects/puzzle_quest/docs/decompiled/battle_ai");
        outDir.mkdirs();

        FunctionManager fnManager = currentProgram.getFunctionManager();

        // Root of the AI heuristic chain reached from CBattleManager::EvaluateBoard (0x00440C20)
        Map<String, Long> roots = new LinkedHashMap<>();
        roots.put("CBattleManager_EvaluateBoard", 0x00440C20L);
        roots.put("BattleAI_ScoreMatchResult_43f970", 0x0043f970L);
        roots.put("BattleAI_PushCandidate_440380", 0x00440380L);
        roots.put("BattleAI_CandidatePush_480470", 0x00480470L);
        roots.put("BattleAI_GetSingleton_43f870", 0x0043f870L);
        roots.put("CBoard_SwapGems_47b280", 0x0047b280L);
        roots.put("CBoard_CheckMatch_47c8c0", 0x0047c8c0L);
        roots.put("CBoard_DestroyGem_47e000", 0x0047e000L);
        roots.put("CBoard_DeleteGem_47ac70", 0x0047ac70L);

        int total = 0;
        for (Map.Entry<String, Long> e : roots.entrySet()) {
            Function f = resolve(fnManager, e.getValue(), e.getKey());
            if (f == null) {
                println("!! could not resolve " + e.getKey());
                continue;
            }
            total += decompileRecursive(f, 2);
        }

        println("=== battle AI decompilation complete: " + total + " functions ===");
    }

    /** Decompile f, then its callees up to depth levels deep. */
    private int decompileRecursive(Function f, int depth) throws Exception {
        long va = f.getEntryPoint().getOffset();
        if (!done.add(va)) {
            return 0;
        }

        int count = 0;
        DecompileResults res = decomp.decompileFunction(f, 90, monitor);
        if (res != null && res.decompileCompleted()) {
            File outFile = new File(outDir, name(f, va) + ".c");
            try (PrintWriter pw = new PrintWriter(outFile)) {
                pw.write(res.getDecompiledFunction().getC());
            }
            count++;
        } else {
            println("!! decompile failed: " + f.getName());
        }

        if (depth <= 0) {
            return count;
        }

        Deque<Function> queue = new ArrayDeque<>(f.getCalledFunctions(monitor));
        Set<Long> seen = new HashSet<>();
        while (!queue.isEmpty()) {
            Function c = queue.poll();
            long cva = c.getEntryPoint().getOffset();
            if (!seen.add(cva)) {
                continue;
            }
            // engine code only; skip CRT/thunks/libc
            if (cva < 0x00401000L || cva >= 0x004F0000L) {
                continue;
            }
            count += decompileRecursive(c, depth - 1);
        }
        return count;
    }

    private Function resolve(FunctionManager fm, long va, String name) {
        Address a = currentProgram.getAddressFactory().getDefaultAddressSpace().getAddress(va);
        Function f = fm.getFunctionAt(a);
        if (f == null) {
            f = fm.getFunctionContaining(a);
        }
        if (f == null) {
            f = createFunction(a, name);
        }
        if (f != null && (f.getName().startsWith("FUN_") || f.getName().equals(name))) {
            try {
                f.setName(name, ghidra.program.model.symbol.SourceType.USER_DEFINED);
            } catch (Exception e) {
                println("rename failed for " + name + ": " + e.getMessage());
            }
        }
        return f;
    }

    private String name(Function f, long va) {
        String n = f.getName();
        if (n.startsWith("FUN_")) {
            return "Sub_" + Long.toHexString(va);
        }
        return n;
    }
}
