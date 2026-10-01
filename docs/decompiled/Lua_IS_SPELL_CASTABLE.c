
void Lua_IS_SPELL_CASTABLE(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  int *piVar3;
  int iVar4;
  undefined4 uVar5;
  char *pcVar6;
  short local_2c;
  short local_2a;
  short local_28;
  short local_26;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00515e38;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    pcVar6 = "IS_SPELL_CASTABLE: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("IS_SPELL_CASTABLE: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar6);
  }
  else {
    FUN_004f6db0(param_1,1);
    uVar2 = FUN_0050432c();
    iVar1 = FUN_004f6ca0(param_1,2);
    if (iVar1 == 0) {
      pcVar6 = "IS_SPELL_CASTABLE: arg 2 is not an integer";
      Engine_ACTIVATE_COMPANION_483650("IS_SPELL_CASTABLE: arg 2 is not an integer");
      Engine_ACTIVATE_COMPANION_4836e0(pcVar6);
    }
    else {
      FUN_004f6db0(param_1,2);
      iVar1 = FUN_0050432c();
      uVar5 = 1;
      Engine_ADD_GOLD_447c60(uVar2);
      piVar3 = (int *)Engine_ADD_GOLD_446200(uVar2);
      iVar1 = *(int *)(piVar3[0xb] + iVar1 * 4);
      iVar4 = Engine_HANDLE_SPELL_COST_4622c0();
      FUN_0040d4d0(*(int *)(iVar4 + 8) + iVar1 * 0x48);
      local_4 = 0;
      if ((char)piVar3[4] != '\0') {
        FUN_00474cb0(*piVar3);
      }
      iVar1 = *piVar3;
      if ((((*(int *)(iVar1 + 0x74) < (int)local_2c) || (*(int *)(iVar1 + 0x78) < (int)local_2a)) ||
          (*(int *)(iVar1 + 0x80) < (int)local_26)) ||
         ((*(int *)(iVar1 + 0x7c) < (int)local_28 || ((char)piVar3[5] == '\0')))) {
        uVar5 = 0;
      }
      FUN_004f71f0(param_1,uVar5);
      local_4 = 0xffffffff;
      FUN_00474b40();
    }
  }
  ExceptionList = local_c;
  FUN_005042e3();
  return;
}

