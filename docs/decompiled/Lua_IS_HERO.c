
undefined4 Lua_IS_HERO(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  char *pcVar3;
  
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    pcVar3 = "IS_HERO: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("IS_HERO: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar3);
    return 0;
  }
  FUN_004f6db0(param_1,1);
  uVar2 = FUN_0050432c();
  Engine_ADD_GOLD_447c60(uVar2);
  iVar1 = Engine_ADD_GOLD_446200(uVar2);
  FUN_004f71f0(param_1,*(char *)(iVar1 + 0x10) != '\0');
  return 1;
}

