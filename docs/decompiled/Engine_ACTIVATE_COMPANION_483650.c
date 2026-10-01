
void __fastcall Engine_ACTIVATE_COMPANION_483650(undefined4 param_1)

{
  int iVar1;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_0051576b;
  local_c = ExceptionList;
  if (DAT_00583104 == 0) {
    ExceptionList = &local_c;
    iVar1 = FUN_004f0184(0x20,param_1);
    local_4 = 0;
    if (iVar1 != 0) {
      DAT_00583104 = FUN_004835d0(iVar1);
      ExceptionList = local_c;
      return;
    }
    DAT_00583104 = 0;
  }
  ExceptionList = local_c;
  return;
}

