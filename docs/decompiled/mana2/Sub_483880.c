
void FUN_00483880(void)

{
  undefined4 uVar1;
  int iVar2;
  undefined1 local_3c [24];
  undefined1 local_24 [12];
  undefined1 local_18 [12];
  void *local_c;
  undefined1 *puStack_8;
  int local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_005157d8;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  Engine_ACTIVATE_COMPANION_4be530(L"Assets\\Scripts",0xffffffff);
  local_4 = 0;
  Engine_ACTIVATE_COMPANION_4be530(L"\\*.lua",0xffffffff);
  local_4._0_1_ = 1;
  FUN_004be790(local_3c);
  local_4 = (uint)local_4._1_3_ << 8;
  Engine_ACTIVATE_COMPANION_4bdf40();
  uVar1 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
  iVar2 = FUN_004d7a20(uVar1);
  while (iVar2 != 0) {
    Engine_ACTIVATE_COMPANION_4be530(L"Assets\\Scripts",0xffffffff);
    local_4._0_1_ = 2;
    Engine_ACTIVATE_COMPANION_4be530(&DAT_0052146c,0xffffffff);
    local_4._0_1_ = 3;
    FUN_004be790(local_24);
    local_4._0_1_ = 2;
    Engine_ACTIVATE_COMPANION_4bdf40();
    Engine_ACTIVATE_COMPANION_4be530(iVar2,0xffffffff);
    local_4._0_1_ = 4;
    FUN_004be790(local_18);
    local_4._0_1_ = 2;
    Engine_ACTIVATE_COMPANION_4bdf40();
    uVar1 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
    FUN_00483720(uVar1);
    iVar2 = FUN_004d7a80();
    local_4 = (uint)local_4._1_3_ << 8;
    Engine_ACTIVATE_COMPANION_4bdf40();
  }
  FUN_004d8010();
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = local_c;
  return;
}

