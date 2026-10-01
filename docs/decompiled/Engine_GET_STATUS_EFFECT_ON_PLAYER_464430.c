
void __fastcall Engine_GET_STATUS_EFFECT_ON_PLAYER_464430(undefined4 param_1)

{
  void *local_c;
  undefined1 *puStack_8;
  undefined4 uStack_4;
  
  uStack_4 = 0xffffffff;
  puStack_8 = &LAB_0051428b;
  local_c = ExceptionList;
  if (DAT_005829b4 == (undefined4 *)0x0) {
    ExceptionList = &local_c;
    DAT_005829b4 = (undefined4 *)FUN_004f0184(0x14,param_1);
    if (DAT_005829b4 != (undefined4 *)0x0) {
      *DAT_005829b4 = &PTR_FUN_00522240;
      DAT_005829b4[2] = 0;
      DAT_005829b4[3] = 0;
      DAT_005829b4[4] = 0;
      ExceptionList = local_c;
      return;
    }
    DAT_005829b4 = (undefined4 *)0x0;
  }
  ExceptionList = local_c;
  return;
}

