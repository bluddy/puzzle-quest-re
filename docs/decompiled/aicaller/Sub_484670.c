
void FUN_00484670(undefined4 param_1)

{
  undefined4 uVar1;
  int iVar2;
  undefined1 local_410 [256];
  undefined1 local_310 [256];
  undefined1 local_210 [256];
  undefined1 auStack_110 [256];
  undefined4 local_10;
  void *local_c;
  undefined1 *puStack_8;
  int local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_005159ad;
  local_c = ExceptionList;
  local_10 = DAT_0057faa0;
  ExceptionList = &local_c;
  uVar1 = FUN_004f6a50();
  Engine_ACTIVATE_COMPANION_4be530(param_1,0xffffffff);
  local_4 = 0;
  FUN_004bdc30(local_310,0xff);
  FUN_004f7090(DAT_00583108,local_310);
  FUN_004f7220(DAT_00583108,0xffffd8ef);
  iVar2 = FUN_004f6c10(DAT_00583108,0xffffffff);
  if (iVar2 == 5) {
    FUN_004bf180();
    local_4._0_1_ = 4;
    FUN_004bdc30(local_410,0xff);
    FUN_004f7090(DAT_00583108,local_410);
    FUN_004f7220(DAT_00583108,0xfffffffe);
    iVar2 = FUN_004f6c10(DAT_00583108,0xffffffff);
    if (iVar2 == 6) {
      iVar2 = Engine_EXTRA_TURN_4646e0();
      FUN_004f7020(DAT_00583108,(double)*(int *)(iVar2 + 4 + *(int *)(iVar2 + 0x28) * 4));
      FUN_004f75f0(DAT_00583108,1,1);
      iVar2 = FUN_004f6ca0(DAT_00583108,0xffffffff);
      if (iVar2 != 0) {
        FUN_004f6db0(DAT_00583108,0xffffffff);
        FUN_0050432c();
        FUN_004f6a60(DAT_00583108,0xfffffffe);
        FUN_004f6a60(DAT_00583108,uVar1);
        local_4 = (uint)local_4._1_3_ << 8;
        Engine_ACTIVATE_COMPANION_4bdf40();
        local_4 = 0xffffffff;
        Engine_ACTIVATE_COMPANION_4bdf40();
        goto LAB_004849b6;
      }
      Engine_ACTIVATE_COMPANION_4be530(L"Number has not been returned: ",0xffffffff);
      local_4._0_1_ = 5;
      Engine_ACTIVATE_COMPANION_4be530(param_1,0xffffffff);
      local_4._0_1_ = 6;
      FUN_004be790();
      local_4._0_1_ = 5;
      Engine_ACTIVATE_COMPANION_4bdf40();
      FUN_004bdc30(auStack_110,0xff);
      Engine_ACTIVATE_COMPANION_483650();
      Engine_ACTIVATE_COMPANION_4836e0();
      FUN_004f6a60(DAT_00583108,uVar1);
      local_4._0_1_ = 4;
      Engine_ACTIVATE_COMPANION_4bdf40();
    }
    else {
      FUN_004f6a60(DAT_00583108,0xfffffffd);
      FUN_004f6a60(DAT_00583108,uVar1);
    }
  }
  else {
    FUN_004f6a60(DAT_00583108,0xfffffffe);
    Engine_ACTIVATE_COMPANION_4be530(L"Spell",0xffffffff);
    local_4._0_1_ = 1;
    Engine_ACTIVATE_COMPANION_4be530(L" object is not a table: ",0xffffffff);
    local_4._0_1_ = 2;
    FUN_004be790();
    local_4._0_1_ = 1;
    Engine_ACTIVATE_COMPANION_4bdf40();
    Engine_ACTIVATE_COMPANION_4be530(param_1,0xffffffff);
    local_4._0_1_ = 3;
    FUN_004be790();
    local_4._0_1_ = 1;
    Engine_ACTIVATE_COMPANION_4bdf40();
    FUN_004bdc30(local_210,0xff);
    Engine_ACTIVATE_COMPANION_483650();
    Engine_ACTIVATE_COMPANION_4836e0();
    FUN_004f6a60(DAT_00583108,uVar1);
  }
  local_4 = (uint)local_4._1_3_ << 8;
  Engine_ACTIVATE_COMPANION_4bdf40();
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
LAB_004849b6:
  ExceptionList = local_c;
  FUN_005042e3();
  return;
}

