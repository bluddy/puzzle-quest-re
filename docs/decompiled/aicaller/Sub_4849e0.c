
void FUN_004849e0(undefined4 param_1,int param_2)

{
  undefined4 uVar1;
  int iVar2;
  undefined1 local_310 [256];
  undefined1 local_210 [256];
  undefined1 local_110 [256];
  undefined4 local_10;
  void *local_c;
  undefined1 *puStack_8;
  uint local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00515ab7;
  local_c = ExceptionList;
  local_10 = DAT_0057faa0;
  if (DAT_005af278 == 1) {
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
      local_4 = CONCAT31(local_4._1_3_,4);
      FUN_004bdc30(local_210,0xff);
      FUN_004f7090(DAT_00583108,local_210);
      FUN_004f7220(DAT_00583108,0xfffffffe);
      iVar2 = FUN_004f6c10(DAT_00583108,0xffffffff);
      if (iVar2 == 6) {
        FUN_004f7020(DAT_00583108,(double)param_2);
        FUN_004f75f0(DAT_00583108,1,0);
        FUN_004f6a60(DAT_00583108,uVar1);
      }
      else {
        FUN_004f6a60(DAT_00583108,0xfffffffd);
        FUN_004f6a60(DAT_00583108,uVar1);
      }
    }
    else {
      FUN_004f6a60(DAT_00583108,0xfffffffe);
      Engine_ACTIVATE_COMPANION_4be530(L"Item",0xffffffff);
      local_4._0_1_ = 1;
      Engine_ACTIVATE_COMPANION_4be530(L" object is not a table: ",0xffffffff);
      local_4._0_1_ = 2;
      FUN_004be790();
      local_4._0_1_ = 1;
      Engine_ACTIVATE_COMPANION_4bdf40();
      Engine_ACTIVATE_COMPANION_4be530(param_1,0xffffffff);
      local_4._0_1_ = 3;
      FUN_004be790();
      local_4 = CONCAT31(local_4._1_3_,1);
      Engine_ACTIVATE_COMPANION_4bdf40();
      FUN_004bdc30(local_110,0xff);
      Engine_ACTIVATE_COMPANION_483650();
      Engine_ACTIVATE_COMPANION_4836e0();
      FUN_004f6a60(DAT_00583108,uVar1);
    }
    local_4 = local_4 & 0xffffff00;
    Engine_ACTIVATE_COMPANION_4bdf40();
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
  }
  ExceptionList = local_c;
  FUN_005042e3();
  return;
}

