
undefined4 Lua_ADD_TEMP_SKILL(undefined4 param_1)

{
  bool bVar1;
  int iVar2;
  undefined4 uVar3;
  int iVar4;
  int *piVar5;
  int iVar6;
  int iVar7;
  int iVar8;
  char *pcVar9;
  int iStack_c;
  
  iVar2 = FUN_004f6ca0(param_1,1);
  if (iVar2 == 0) {
    pcVar9 = "ADD_TEMP_SKILL: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("ADD_TEMP_SKILL: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar9);
    return 0;
  }
  FUN_004f6db0(param_1,1);
  uVar3 = FUN_0050432c();
  iVar2 = FUN_004f6ca0(param_1,2);
  if (iVar2 == 0) {
    pcVar9 = "ADD_TEMP_SKILL: arg 2 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("ADD_TEMP_SKILL: arg 2 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar9);
    return 0;
  }
  FUN_004f6db0(param_1,2);
  iVar2 = FUN_0050432c();
  iVar4 = FUN_004f6ca0(param_1,3);
  if (iVar4 == 0) {
    pcVar9 = "ADD_TEMP_SKILL: arg 3 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("ADD_TEMP_SKILL: arg 3 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar9);
    return 0;
  }
  FUN_004f6db0(param_1,3);
  iStack_c = FUN_0050432c();
  Engine_ADD_GOLD_447c60(uVar3);
  piVar5 = (int *)Engine_ADD_GOLD_446200(uVar3);
  if ((((iVar2 == 0) || (iVar2 == 2)) || (iVar2 == 1)) || (bVar1 = false, iVar2 == 3)) {
    bVar1 = true;
  }
  iVar6 = FUN_00465f30(iVar2);
  iVar7 = FUN_00465f30(6);
  iVar8 = 0;
  iVar4 = 0;
  if (bVar1) {
    iVar4 = *(int *)(*piVar5 + 0x84 + iVar2 * 4);
    iVar8 = FUN_00465f60(3,iVar2);
    iVar8 = iVar8 + 0x19;
  }
  if (999 < iVar6 + iStack_c) {
    iStack_c = 999 - iVar6;
  }
  piVar5[iVar2 + 0x1a] = piVar5[iVar2 + 0x1a] + iStack_c;
  if (bVar1) {
    iVar6 = FUN_00465f60(3,iVar2);
    FUN_004839f0(iVar2,((iVar6 + 0x19) - iVar8) + iVar4);
  }
  iVar2 = FUN_00465f30(6);
  if (iVar7 != iVar2) {
    iVar2 = FUN_00478620(7,iVar2);
    iVar4 = FUN_00478620(7,iVar7);
    iVar2 = iVar2 - iVar4;
    if (iVar2 != 0) {
      Engine_ADD_LIFE_445c40(iVar2);
      FUN_00445c80(iVar2);
    }
  }
  return 0;
}

