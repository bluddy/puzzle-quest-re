
void __fastcall Engine_QUEST_ADD_AWARD_441ed0(undefined4 param_1)

{
  void *local_c;
  undefined1 *puStack_8;
  undefined4 uStack_4;
  
  uStack_4 = 0xffffffff;
  puStack_8 = &LAB_0051228b;
  local_c = ExceptionList;
  if (DAT_005828e0 == (undefined4 *)0x0) {
    ExceptionList = &local_c;
    DAT_005828e0 = (undefined4 *)FUN_004f0184(0x14,param_1);
    if (DAT_005828e0 != (undefined4 *)0x0) {
      *DAT_005828e0 = &PTR_FUN_00521398;
      DAT_005828e0[2] = 0;
      DAT_005828e0[3] = 0;
      DAT_005828e0[4] = 0;
      ExceptionList = local_c;
      return;
    }
    DAT_005828e0 = (undefined4 *)0x0;
  }
  ExceptionList = local_c;
  return;
}

