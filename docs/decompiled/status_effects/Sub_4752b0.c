
void __fastcall FUN_004752b0(undefined4 *param_1)

{
  void *local_c;
  undefined1 *puStack_8;
  int local_4;
  
  puStack_8 = &LAB_00514dd1;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  *param_1 = &PTR_FUN_0051ca64;
  local_4 = 2;
  Engine_ACTIVATE_COMPANION_4bdf40();
  local_4._0_1_ = 1;
  Engine_ACTIVATE_COMPANION_4bdf40();
  local_4 = (uint)local_4._1_3_ << 8;
  Engine_ACTIVATE_COMPANION_4bdf40();
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = local_c;
  return;
}

