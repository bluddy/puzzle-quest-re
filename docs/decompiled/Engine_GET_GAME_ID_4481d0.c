
void __fastcall Engine_GET_GAME_ID_4481d0(undefined4 param_1)

{
  int iVar1;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_005128bb;
  local_c = ExceptionList;
  if (DAT_005828f8 == 0) {
    ExceptionList = &local_c;
    iVar1 = FUN_004f0184(0x8c,param_1);
    local_4 = 0;
    if (iVar1 != 0) {
      DAT_005828f8 = FUN_00448150(iVar1);
      ExceptionList = local_c;
      return;
    }
    DAT_005828f8 = 0;
  }
  ExceptionList = local_c;
  return;
}

