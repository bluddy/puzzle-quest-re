
undefined4 Lua_TUTORIAL_GLOW_RECT(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  undefined4 uVar3;
  undefined4 uVar4;
  undefined4 uVar5;
  char *pcVar6;
  
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    pcVar6 = "TUTORIAL_GLOW_RECT: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("TUTORIAL_GLOW_RECT: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar6);
    return 0;
  }
  FUN_004f6db0(param_1,1);
  uVar2 = FUN_0050432c();
  iVar1 = FUN_004f6ca0(param_1,2);
  if (iVar1 == 0) {
    pcVar6 = "TUTORIAL_GLOW_RECT: arg 2 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("TUTORIAL_GLOW_RECT: arg 2 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar6);
    return 0;
  }
  FUN_004f6db0(param_1,2);
  uVar3 = FUN_0050432c();
  iVar1 = FUN_004f6ca0(param_1,3);
  if (iVar1 == 0) {
    pcVar6 = "TUTORIAL_GLOW_RECT: arg 3 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("TUTORIAL_GLOW_RECT: arg 3 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar6);
    return 0;
  }
  FUN_004f6db0(param_1,3);
  uVar4 = FUN_0050432c();
  iVar1 = FUN_004f6ca0(param_1,4);
  if (iVar1 == 0) {
    pcVar6 = "TUTORIAL_GLOW_RECT: arg 4 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("TUTORIAL_GLOW_RECT: arg 4 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar6);
    return 0;
  }
  FUN_004f6db0(param_1,4);
  uVar5 = FUN_0050432c();
  FUN_00483a90(uVar2,uVar3,uVar4,uVar5);
  return 0;
}

