
undefined4 Lua_GET_RESISTANCE(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  int iVar3;
  int *piVar4;
  uint uVar5;
  uint uVar6;
  char *pcVar7;
  
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    pcVar7 = "GET_RESISTANCE: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("GET_RESISTANCE: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar7);
    return 0;
  }
  FUN_004f6db0(param_1,1);
  uVar2 = FUN_0050432c();
  iVar1 = FUN_004f6ca0(param_1,2);
  if (iVar1 == 0) {
    pcVar7 = "GET_RESISTANCE: arg 2 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("GET_RESISTANCE: arg 2 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar7);
    return 0;
  }
  FUN_004f6db0(param_1,2);
  iVar3 = FUN_0050432c();
  Engine_ADD_GOLD_447c60(uVar2);
  piVar4 = (int *)Engine_ADD_GOLD_446200(uVar2);
  piVar4 = (int *)*piVar4;
  iVar1 = piVar4[0x11];
  iVar3 = piVar4[iVar3 + 0x2b];
  uVar5 = (**(code **)(*piVar4 + 0x20))();
  uVar5 = uVar5 & ((int)uVar5 < 1) - 1;
  uVar6 = 100;
  if ((int)uVar5 < 0x65) {
    uVar6 = uVar5;
  }
  FUN_004f7020(param_1,(double)(int)uVar6,iVar3,iVar1);
  return 1;
}

