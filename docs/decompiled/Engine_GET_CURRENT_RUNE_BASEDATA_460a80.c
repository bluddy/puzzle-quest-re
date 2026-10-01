
void __fastcall Engine_GET_CURRENT_RUNE_BASEDATA_460a80(undefined4 param_1)

{
  int iVar1;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00513e8b;
  local_c = ExceptionList;
  if (DAT_005829a8 == 0) {
    ExceptionList = &local_c;
    iVar1 = FUN_004f0184(0x44,param_1);
    local_4 = 0;
    if (iVar1 != 0) {
      DAT_005829a8 = FUN_004609b0(iVar1);
      ExceptionList = local_c;
      return;
    }
    DAT_005829a8 = 0;
  }
  ExceptionList = local_c;
  return;
}

