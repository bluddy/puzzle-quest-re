
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void FUN_0043f5b0(undefined4 param_1,undefined4 param_2,undefined4 param_3,int param_4,int param_5)

{
  short sVar1;
  int *piVar2;
  int *piVar3;
  int iVar4;
  undefined4 uVar5;
  undefined1 *puVar6;
  undefined1 auStack_24 [12];
  undefined1 auStack_18 [12];
  void *pvStack_c;
  undefined1 *puStack_8;
  int iStack_4;
  
  iStack_4 = 0xffffffff;
  puStack_8 = &LAB_00512100;
  pvStack_c = ExceptionList;
  ExceptionList = &pvStack_c;
  FUN_004c2340();
  FUN_00421e30(0x5dc);
  if (DAT_00582884 == '\0') {
    FUN_004c5e50(L"Assets\\Screens\\YesNoMenu.xml");
  }
  FUN_004c27d0(0xffffffff,0xffffffff);
  FUN_0043f440(0,param_1);
  piVar2 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"str_message");
  piVar3 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"str_message2");
  FUN_004b2ba0(L"font_system");
  sVar1 = FUN_004c6a90(param_2);
  iVar4 = (**(code **)(DAT_00582868 + 0x68))();
  if (iVar4 < sVar1) {
    if (piVar3 != (int *)0x0) {
      (**(code **)(*piVar3 + 0x10))(param_2);
    }
    if (piVar2 == (int *)0x0) goto LAB_0043f6a2;
    iVar4 = *piVar2;
  }
  else {
    if (piVar2 != (int *)0x0) {
      (**(code **)(*piVar2 + 0x10))(param_2);
    }
    if (piVar3 == (int *)0x0) goto LAB_0043f6a2;
    iVar4 = *piVar3;
  }
  (**(code **)(iVar4 + 0x10))(&DAT_0051b07c);
LAB_0043f6a2:
  _DAT_005828d4 = param_3;
  if (param_4 == 0) {
    Engine_ACTIVATE_COMPANION_4be530(L"[YES]",0xffffffff);
    puVar6 = auStack_24;
    iStack_4 = param_4;
    Engine_GET_TEXT_4b4500(puVar6);
    Engine_GET_TEXT_4b4050(puVar6);
    uVar5 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
    piVar2 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"butt_yes");
    if (piVar2 != (int *)0x0) {
      (**(code **)(*piVar2 + 0x10))(uVar5);
    }
    piVar2 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"gp_yes");
    if (piVar2 != (int *)0x0) {
      (**(code **)(*piVar2 + 0x10))(uVar5);
    }
    iStack_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
  }
  else {
    piVar2 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"butt_yes");
    if (piVar2 != (int *)0x0) {
      (**(code **)(*piVar2 + 0x10))(param_4);
    }
    piVar2 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"gp_yes");
    if (piVar2 != (int *)0x0) {
      (**(code **)(*piVar2 + 0x10))(param_4);
    }
  }
  if (param_5 == 0) {
    Engine_ACTIVATE_COMPANION_4be530(L"[NO]",0xffffffff);
    puVar6 = auStack_18;
    iStack_4 = 1;
    Engine_GET_TEXT_4b4500(puVar6);
    Engine_GET_TEXT_4b4050(puVar6);
    uVar5 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
    piVar2 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"butt_no");
    if (piVar2 != (int *)0x0) {
      (**(code **)(*piVar2 + 0x10))(uVar5);
    }
    piVar2 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"gp_no");
    if (piVar2 != (int *)0x0) {
      (**(code **)(*piVar2 + 0x10))(uVar5);
    }
    iStack_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    ExceptionList = pvStack_c;
    return;
  }
  piVar2 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"butt_no");
  if (piVar2 != (int *)0x0) {
    (**(code **)(*piVar2 + 0x10))(param_5);
  }
  piVar2 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"gp_no");
  if (piVar2 != (int *)0x0) {
    (**(code **)(*piVar2 + 0x10))(param_5);
  }
  ExceptionList = pvStack_c;
  return;
}

