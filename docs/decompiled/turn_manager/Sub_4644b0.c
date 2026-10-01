
void __fastcall FUN_004644b0(int param_1)

{
  char cVar1;
  undefined4 uVar2;
  int iVar3;
  int iVar4;
  undefined1 local_80 [24];
  undefined1 local_68 [12];
  undefined1 local_5c [12];
  undefined1 local_50 [68];
  void *local_c;
  undefined1 *puStack_8;
  int local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_005142d0;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  Engine_ACTIVATE_COMPANION_4be530(L"Assets\\StatusEffects",0xffffffff);
  local_4 = 0;
  Engine_ACTIVATE_COMPANION_4be530(L"\\*.xml",0xffffffff);
  local_4._0_1_ = 1;
  FUN_004be790(local_80);
  local_4 = (uint)local_4._1_3_ << 8;
  Engine_ACTIVATE_COMPANION_4bdf40();
  uVar2 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
  iVar3 = FUN_004d7a20(uVar2);
  while (iVar3 != 0) {
    FUN_00475240();
    local_4._0_1_ = 2;
    Engine_ACTIVATE_COMPANION_4be530(L"Assets\\StatusEffects",0xffffffff);
    local_4._0_1_ = 3;
    Engine_ACTIVATE_COMPANION_4be530(&DAT_0052146c,0xffffffff);
    local_4._0_1_ = 4;
    FUN_004be790(local_68);
    local_4._0_1_ = 3;
    Engine_ACTIVATE_COMPANION_4bdf40();
    Engine_ACTIVATE_COMPANION_4be530(iVar3,0xffffffff);
    local_4._0_1_ = 5;
    FUN_004be790(local_5c);
    local_4 = CONCAT31(local_4._1_3_,3);
    Engine_ACTIVATE_COMPANION_4bdf40();
    uVar2 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
    cVar1 = FUN_00475760(uVar2);
    if (cVar1 != '\0') {
      FUN_00464390(local_50);
    }
    iVar3 = FUN_004d7a80();
    local_4._0_1_ = 2;
    Engine_ACTIVATE_COMPANION_4bdf40();
    local_4 = (uint)local_4._1_3_ << 8;
    FUN_004752b0();
  }
  FUN_004d8010();
  iVar3 = 0;
  while( true ) {
    iVar4 = *(int *)(param_1 + 8);
    if (iVar4 != 0) {
      iVar4 = (*(int *)(param_1 + 0xc) - iVar4) / 0x44;
    }
    if (iVar4 <= iVar3) break;
    FUN_00475320();
    iVar3 = iVar3 + 1;
  }
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = local_c;
  return;
}

