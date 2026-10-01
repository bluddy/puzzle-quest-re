
void Engine_IS_DEMO_4de1a0(void)

{
  undefined4 *puVar1;
  undefined4 *puVar2;
  undefined4 uVar3;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00518a9b;
  local_c = ExceptionList;
  if (DAT_005affdc == (undefined4 *)0x0) {
    ExceptionList = &local_c;
    puVar1 = (undefined4 *)FUN_004f0184(0xc);
    local_4 = 0;
    if (puVar1 == (undefined4 *)0x0) {
      DAT_005affdc = (undefined4 *)0x0;
    }
    else {
      puVar2 = puVar1 + 1;
      uVar3 = 4;
      *puVar1 = &PTR_FUN_0052e220;
      puVar1[2] = 0;
      *puVar2 = 0x2b00b1e5;
      Engine_ADD_MAX_LIFE_445030(puVar2,4);
      FUN_00444ef0(puVar2,uVar3);
      DAT_005affdc = puVar1;
    }
  }
  ExceptionList = local_c;
  return;
}

