
void Engine_QUEST_MESSAGE_42bef0
               (undefined4 param_1,undefined4 param_2,undefined4 param_3,undefined4 param_4)

{
  int iVar1;
  int iVar2;
  undefined1 local_2c [24];
  undefined4 local_14;
  undefined4 local_10;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00511028;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  FUN_004bdb30();
  local_4 = 0;
  FUN_004bdb30();
  local_4 = 1;
  FUN_004be780(param_1);
  FUN_004be780(param_2);
  iVar1 = DAT_00581a0c;
  local_14 = param_3;
  local_10 = param_4;
  iVar2 = FUN_0042bdc0(DAT_00581a0c,*(undefined4 *)(DAT_00581a0c + 4),local_2c);
  FUN_0042be50(1);
  *(int *)(iVar1 + 4) = iVar2;
  **(int **)(iVar2 + 4) = iVar2;
  local_4 = 2;
  Engine_ACTIVATE_COMPANION_4bdf40();
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = local_c;
  return;
}

