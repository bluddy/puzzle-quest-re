
void Engine_ADD_MAX_LIFE_445030(void)

{
  undefined4 *puVar1;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 uStack_4;
  
  uStack_4 = 0xffffffff;
  puStack_8 = &LAB_0051262b;
  local_c = ExceptionList;
  if (DAT_005828ec == (undefined4 *)0x0) {
    ExceptionList = &local_c;
    puVar1 = (undefined4 *)FUN_004f0184(0x18);
    if (puVar1 == (undefined4 *)0x0) {
      DAT_005828ec = (undefined4 *)0x0;
    }
    else {
      *puVar1 = &PTR_FUN_00521630;
      puVar1[2] = 0;
      puVar1[3] = 0;
      puVar1[4] = 0;
      FUN_00444e50();
      puVar1[5] = 0;
      DAT_005828ec = puVar1;
    }
  }
  ExceptionList = local_c;
  return;
}

