
undefined4 Lua_QUEST_IS_VISIBLE(undefined4 param_1)

{
  char cVar1;
  int iVar2;
  char *pcVar3;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00515e58;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  local_4 = 0;
  iVar2 = FUN_004f6d00(param_1,1);
  if (iVar2 == 0) {
    pcVar3 = "QUEST_IS_VISIBLE: arg 1 is not a string";
    Engine_ACTIVATE_COMPANION_483650("QUEST_IS_VISIBLE: arg 1 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar3);
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    ExceptionList = local_c;
    return 0;
  }
  FUN_004f6e50(param_1,1);
  Engine_ACTIVATE_COMPANION_4bf1a0();
  Engine_ACTIVATE_COMPANION_4be7e0();
  Engine_ACTIVATE_COMPANION_4be7e0();
  Engine_ACTIVATE_COMPANION_4be7e0();
  Engine_ACTIVATE_COMPANION_4be7e0();
  Engine_QUEST_ENCOUNTER_ADD_4556f0();
  cVar1 = FUN_00451020();
  FUN_004f7020(param_1,(double)(int)cVar1);
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = local_c;
  return 1;
}

