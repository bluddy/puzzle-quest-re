
void __thiscall
Engine_QUEST_ENCOUNTER_BATTLE_450070
          (int param_1,undefined4 param_2,undefined4 param_3,undefined4 param_4,undefined4 param_5)

{
  int iVar1;
  undefined4 uVar2;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00512fdb;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  iVar1 = FUN_004f0184(0xa8);
  local_4 = 0;
  if (iVar1 == 0) {
    uVar2 = 0;
  }
  else {
    uVar2 = FUN_0047e980();
  }
  local_4 = 0xffffffff;
  *(undefined4 *)(param_1 + 0x88) = uVar2;
  FUN_0047f960(param_2,param_3,param_4,param_5);
  ExceptionList = local_c;
  return;
}

