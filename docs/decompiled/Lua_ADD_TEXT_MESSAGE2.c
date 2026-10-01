
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

undefined4 Lua_ADD_TEXT_MESSAGE2(undefined4 param_1)

{
  short sVar1;
  short sVar2;
  int iVar3;
  undefined4 uVar4;
  undefined4 uVar5;
  undefined4 uVar6;
  int iVar7;
  int iVar8;
  int iVar9;
  char *pcVar10;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00515e58;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  local_4 = 0;
  iVar3 = FUN_004f6d00(param_1,1);
  if (iVar3 == 0) {
    pcVar10 = "ADD_TEXT_MESSAGE2: arg 1 is not a string";
  }
  else {
    uVar4 = FUN_004f6e50(param_1,1);
    Engine_ACTIVATE_COMPANION_4bf1a0(uVar4);
    iVar3 = FUN_004f6ca0(param_1,2);
    if (iVar3 == 0) {
      pcVar10 = "ADD_TEXT_MESSAGE2: arg 2 is not a floating point number";
    }
    else {
      FUN_004f6db0(param_1,2);
      iVar3 = FUN_004f6ca0(param_1,3);
      if (iVar3 != 0) {
        FUN_004f6db0(param_1,3);
        uVar5 = FUN_0050432c();
        uVar4 = _DAT_0059a4c8;
        sVar2 = Engine_ADD_TEXT_MESSAGE_4bc4c0();
        sVar1 = DAT_0059a4ca;
        iVar7 = (int)sVar2 + (int)(short)uVar4 / 2;
        sVar2 = Engine_ADD_TEXT_MESSAGE_4bc490();
        iVar8 = sVar2 + 0x24 + (int)sVar1 / 2;
        uVar4 = FUN_0050432c();
        iVar3 = iVar8 + -0x28;
        iVar9 = iVar7;
        uVar6 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(uVar5,iVar7,iVar8,iVar7,iVar3,uVar4);
        Engine_ADD_TEXT_MESSAGE_415120(uVar6,uVar5,iVar7,iVar8,iVar9,iVar3,uVar4);
        local_4 = 0xffffffff;
        Engine_ACTIVATE_COMPANION_4bdf40();
        ExceptionList = local_c;
        return 0;
      }
      pcVar10 = "ADD_TEXT_MESSAGE2: arg 3 is not an integer";
    }
  }
  Engine_ACTIVATE_COMPANION_483650(pcVar10);
  Engine_ACTIVATE_COMPANION_4836e0(pcVar10);
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = local_c;
  return 0;
}

