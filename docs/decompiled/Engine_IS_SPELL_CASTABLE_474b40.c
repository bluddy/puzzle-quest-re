
void __fastcall Engine_IS_SPELL_CASTABLE_474b40(undefined4 *param_1)

{
  void *local_c;
  undefined1 *puStack_8;
  uint local_4;
  
  puStack_8 = &LAB_00514d46;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  *param_1 = &PTR_FUN_0051c760;
  local_4 = 1;
  Engine_ACTIVATE_COMPANION_4bdf40();
  local_4 = local_4 & 0xffffff00;
  Engine_ACTIVATE_COMPANION_4bdf40();
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = local_c;
  return;
}

