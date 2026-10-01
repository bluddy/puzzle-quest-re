
void Engine_HANDLE_SPELL_COST_4622c0(void)

{
  void *local_c;
  undefined1 *puStack_8;
  undefined4 uStack_4;
  
  uStack_4 = 0xffffffff;
  puStack_8 = &LAB_0051403b;
  local_c = ExceptionList;
  if (DAT_005829ac == (undefined4 *)0x0) {
    ExceptionList = &local_c;
    DAT_005829ac = (undefined4 *)FUN_004f0184(0x1c);
    if (DAT_005829ac != (undefined4 *)0x0) {
      *DAT_005829ac = &PTR_FUN_005221c4;
      DAT_005829ac[2] = 0;
      DAT_005829ac[3] = 0;
      DAT_005829ac[4] = 0;
      *(undefined1 *)(DAT_005829ac + 5) = 0;
      DAT_005829ac[6] = 0;
      ExceptionList = local_c;
      return;
    }
    DAT_005829ac = (undefined4 *)0x0;
  }
  ExceptionList = local_c;
  return;
}

