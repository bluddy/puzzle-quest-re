
undefined4 Lua_QUEST_GET_CITY_STATUS(undefined4 param_1)

{
  int iVar1;
  ulonglong uVar2;
  char *pcVar3;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00515e58;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  Engine_ACTIVATE_COMPANION_4be530();
  local_4 = 0;
  iVar1 = FUN_004f6d00();
  if (iVar1 == 0) {
    pcVar3 = "QUEST_GET_CITY_STATUS: arg 1 is not a string";
    Engine_ACTIVATE_COMPANION_483650("QUEST_GET_CITY_STATUS: arg 1 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar3);
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    ExceptionList = local_c;
    return 0;
  }
  FUN_004f6e50(param_1,1);
  Engine_ACTIVATE_COMPANION_4bf1a0();
  iVar1 = Engine_QUEST_ENCOUNTER_ADD_4556f0();
  uVar2 = (ulonglong)*(uint *)(iVar1 + 0x40);
  Engine_QUEST_ABANDON_44e920(*(uint *)(iVar1 + 0x40),0);
  Engine_QUEST_ABANDON_44d8e0(uVar2);
  FUN_004bdda0();
  iVar1 = FUN_00437800();
  FUN_004f7020(param_1,(double)*(byte *)(iVar1 + 6));
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = local_c;
  return 1;
}

