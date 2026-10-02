
undefined4 Lua_GET_SKILL(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  undefined4 uVar3;
  char *pcVar4;
  
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    pcVar4 = "GET_SKILL: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("GET_SKILL: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
    return 0;
  }
  uVar3 = 1;
  uVar2 = param_1;
  FUN_004f6db0();
  FUN_0050432c();
  iVar1 = FUN_004f6ca0(param_1,2,uVar2,uVar3);
  if (iVar1 == 0) {
    pcVar4 = "GET_SKILL: arg 2 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("GET_SKILL: arg 2 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
    return 0;
  }
  FUN_004f6db0(param_1,2);
  FUN_0050432c();
  Engine_ADD_GOLD_447c60();
  Engine_ADD_GOLD_446200();
  iVar1 = Engine_ADD_TEMP_SKILL_465f30();
  FUN_004f7020(param_1,(double)iVar1);
  return 1;
}

