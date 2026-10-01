
void __fastcall Engine_ADD_ANIMEFFECT_TO_GRID_47a820(undefined4 param_1)

{
  int iVar1;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_0051526b;
  local_c = ExceptionList;
  if (DAT_005830d8 == 0) {
    ExceptionList = &local_c;
    iVar1 = FUN_004f0184(0x42c,param_1);
    local_4 = 0;
    if (iVar1 != 0) {
      DAT_005830d8 = FUN_0047a730(iVar1);
      ExceptionList = local_c;
      return;
    }
    DAT_005830d8 = 0;
  }
  ExceptionList = local_c;
  return;
}

