
void __fastcall Engine_GET_TEXT_4b4500(undefined4 param_1)

{
  int iVar1;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_0051722b;
  local_c = ExceptionList;
  if (DAT_0059a43c == 0) {
    ExceptionList = &local_c;
    iVar1 = FUN_004f0184(0x28,param_1);
    local_4 = 0;
    if (iVar1 != 0) {
      DAT_0059a43c = FUN_004b43b0(iVar1);
      ExceptionList = local_c;
      return;
    }
    DAT_0059a43c = 0;
  }
  ExceptionList = local_c;
  return;
}

