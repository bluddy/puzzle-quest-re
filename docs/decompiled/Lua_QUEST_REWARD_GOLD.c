
undefined4 Lua_QUEST_REWARD_GOLD(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  char *pcVar3;
  
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    pcVar3 = "QUEST_REWARD_GOLD: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("QUEST_REWARD_GOLD: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar3);
    return 0;
  }
  FUN_004f6db0(param_1,1);
  uVar2 = FUN_0050432c();
  FUN_0042d0c0(uVar2);
  return 0;
}

