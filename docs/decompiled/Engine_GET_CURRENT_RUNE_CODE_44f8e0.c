
void __fastcall Engine_GET_CURRENT_RUNE_CODE_44f8e0(undefined4 param_1)

{
  int iVar1;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00512f0b;
  local_c = ExceptionList;
  if (DAT_0058296c == 0) {
    ExceptionList = &local_c;
    iVar1 = FUN_004f0184(0x68,param_1);
    local_4 = 0;
    if (iVar1 != 0) {
      DAT_0058296c = FUN_0044f810(iVar1);
      ExceptionList = local_c;
      return;
    }
    DAT_0058296c = 0;
  }
  ExceptionList = local_c;
  return;
}

