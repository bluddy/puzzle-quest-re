
undefined4 Lua_ADD_TEXT_MESSAGE_TO_CHARACTER2(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  undefined4 uVar3;
  undefined4 uVar4;
  int iVar5;
  int iVar6;
  short sVar7;
  float10 fVar8;
  int iVar9;
  char *pcVar10;
  short sStack_20;
  short sStack_1e;
  float fStack_1c;
  void *pvStack_c;
  undefined1 *puStack_8;
  undefined4 uStack_4;
  
  uStack_4 = 0xffffffff;
  puStack_8 = &LAB_00515e58;
  pvStack_c = ExceptionList;
  ExceptionList = &pvStack_c;
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    pcVar10 = "ADD_TEXT_MESSAGE_TO_CHARACTER2: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("ADD_TEXT_MESSAGE_TO_CHARACTER2: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar10);
    ExceptionList = pvStack_c;
    return 0;
  }
  FUN_004f6db0(param_1,1);
  uVar2 = FUN_0050432c();
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  uStack_4 = 0;
  iVar1 = FUN_004f6d00(param_1,2);
  if (iVar1 == 0) {
    pcVar10 = "ADD_TEXT_MESSAGE_TO_CHARACTER2: arg 2 is not a string";
    Engine_ACTIVATE_COMPANION_483650("ADD_TEXT_MESSAGE_TO_CHARACTER2: arg 2 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar10);
  }
  else {
    uVar3 = FUN_004f6e50(param_1,2);
    Engine_ACTIVATE_COMPANION_4bf1a0(uVar3);
    iVar1 = FUN_004f6ca0(param_1,3);
    if (iVar1 == 0) {
      pcVar10 = "ADD_TEXT_MESSAGE_TO_CHARACTER2: arg 3 is not a floating point number";
      Engine_ACTIVATE_COMPANION_483650
                ("ADD_TEXT_MESSAGE_TO_CHARACTER2: arg 3 is not a floating point number");
      Engine_ACTIVATE_COMPANION_4836e0(pcVar10);
    }
    else {
      fVar8 = (float10)FUN_004f6db0(param_1,3);
      fStack_1c = (float)fVar8;
      iVar1 = FUN_004f6ca0(param_1,4);
      if (iVar1 == 0) {
        pcVar10 = "ADD_TEXT_MESSAGE_TO_CHARACTER2: arg 4 is not an integer";
        Engine_ACTIVATE_COMPANION_483650("ADD_TEXT_MESSAGE_TO_CHARACTER2: arg 4 is not an integer");
        Engine_ACTIVATE_COMPANION_4836e0(pcVar10);
      }
      else {
        FUN_004f6db0(param_1,4);
        uVar3 = FUN_0050432c();
        Engine_ADD_ANIMEFFECT_TO_CHARACTER_475a10(&sStack_20,uVar2);
        sVar7 = sStack_1e + 0x1e;
        sStack_1e = sVar7;
        uVar2 = FUN_0050432c();
        iVar6 = (int)sStack_20;
        iVar5 = (int)sVar7;
        iVar1 = iVar5 + -0x14;
        iVar9 = iVar6;
        uVar4 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(uVar3,iVar6,iVar5,iVar6,iVar1,uVar2);
        Engine_ADD_TEXT_MESSAGE_415120(uVar4,uVar3,iVar6,iVar5,iVar9,iVar1,uVar2);
      }
    }
  }
  uStack_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = pvStack_c;
  return 0;
}

