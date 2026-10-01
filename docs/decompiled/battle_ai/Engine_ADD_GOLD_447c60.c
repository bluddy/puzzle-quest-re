
void Engine_ADD_GOLD_447c60(void)

{
  void *local_c;
  undefined1 *puStack_8;
  undefined4 uStack_4;
  
  uStack_4 = 0xffffffff;
  puStack_8 = &LAB_0051279b;
  local_c = ExceptionList;
  if (DAT_005828f4 == (undefined4 *)0x0) {
    ExceptionList = &local_c;
    DAT_005828f4 = (undefined4 *)FUN_004f0184(0x18);
    if (DAT_005828f4 != (undefined4 *)0x0) {
      *DAT_005828f4 = &PTR_FUN_0052166c;
      DAT_005828f4[2] = 0;
      DAT_005828f4[3] = 0;
      DAT_005828f4[4] = 0;
      DAT_005828f4[5] = 0;
      ExceptionList = local_c;
      return;
    }
    DAT_005828f4 = (undefined4 *)0x0;
  }
  ExceptionList = local_c;
  return;
}

