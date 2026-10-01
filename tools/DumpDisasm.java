// Print disassembly for an address range.
// @category Analysis

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.InstructionIterator;

public class DumpDisasm extends GhidraScript {

    @Override
    public void run() throws Exception {
        long from = Long.decode(getScriptArgs()[0]);
        long to = Long.decode(getScriptArgs()[1]);
        Address a = currentProgram.getAddressFactory().getDefaultAddressSpace().getAddress(from);
        Address b = currentProgram.getAddressFactory().getDefaultAddressSpace().getAddress(to);
        InstructionIterator it = currentProgram.getListing().getInstructions(a, true);
        while (it.hasNext()) {
            Instruction ins = it.next();
            if (ins.getAddress().compareTo(b) > 0) {
                break;
            }
            println(ins.getAddress() + "  " + ins);
        }
    }
}
