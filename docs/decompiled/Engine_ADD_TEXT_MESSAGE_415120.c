
void __thiscall
Engine_ADD_TEXT_MESSAGE_415120
          (int param_1,undefined4 param_2,undefined4 param_3,int param_4,int param_5,int param_6,
          int param_7,int param_8)

{
  short sVar1;
  short sVar2;
  int iVar3;
  undefined4 uVar4;
  int iVar5;
  short sVar6;
  short sVar7;
  int iVar8;
  int iVar9;
  int iVar10;
  int iVar11;
  undefined4 local_48 [4];
  undefined4 local_38;
  int local_34;
  int local_30;
  int local_2c;
  int local_28;
  int local_24;
  int local_20;
  int local_1c;
  int local_18;
  undefined4 local_14;
  int local_10;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00510178;
  local_c = ExceptionList;
  if (*(char *)(param_1 + 0x1e) != '\0') {
    ExceptionList = &local_c;
    FUN_004bdb30();
    local_4 = 0;
    local_48[0] = 0;
    FUN_004be780(param_2);
    local_38 = param_3;
    local_2c = param_6;
    local_28 = param_7;
    local_18 = DAT_0057f484 + param_8;
    local_30 = param_5;
    local_20 = param_5;
    local_10 = param_8 / 2 + DAT_0057f484;
    local_1c = DAT_0057f484;
    local_34 = param_4;
    local_24 = param_4;
    local_14 = 0xff;
    FUN_00414c30(local_48);
    if (*(int *)(param_1 + 0x80) == 0) {
      iVar3 = 0;
    }
    else {
      iVar3 = (*(int *)(param_1 + 0x84) - *(int *)(param_1 + 0x80)) / 0x3c;
    }
    iVar11 = (iVar3 + -1) * 0x3c;
    FUN_0040dd20(*(undefined4 *)(iVar11 + 0x10 + *(int *)(param_1 + 0x80)));
    uVar4 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
    sVar1 = FUN_004c6a90(uVar4);
    uVar4 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
    sVar2 = FUN_004c6ab0(uVar4);
    iVar3 = param_4;
    if (param_6 <= param_4) {
      iVar3 = param_6;
    }
    sVar6 = (short)iVar3 - sVar1 / 2;
    iVar3 = param_7;
    if (param_5 < param_7) {
      iVar3 = param_5;
    }
    sVar7 = (short)iVar3 - sVar2 / 2;
    iVar3 = param_4;
    if ((param_6 < param_4) || (iVar3 = param_6, param_6 <= param_4)) {
      param_4 = param_6;
    }
    iVar5 = param_5;
    if ((param_7 < param_5) || (iVar5 = param_7, param_7 <= param_5)) {
      param_5 = param_7;
    }
    iVar3 = (int)(short)(((short)iVar3 - (short)param_4) + sVar1);
    iVar10 = (int)sVar6;
    iVar9 = 0;
    iVar8 = 0;
    if (DAT_0059a4c8 + -0x14 <= iVar10 + iVar3) {
      iVar9 = ((DAT_0059a4c8 - iVar10) - iVar3) + -0x14;
    }
    iVar3 = (int)sVar7;
    if (DAT_0059a4ca + -0x14 <= iVar3) {
      iVar8 = (((int)DAT_0059a4ca - (int)(short)(((short)iVar5 - (short)param_5) + sVar2)) - iVar3)
              + -0x14;
    }
    if (sVar6 < 0x14) {
      iVar9 = 0x14 - iVar10;
    }
    if (sVar7 < 0x14) {
      iVar8 = 0x14 - iVar3;
    }
    *(int *)(iVar11 + 0x14 + *(int *)(param_1 + 0x80)) =
         *(int *)(iVar11 + 0x14 + *(int *)(param_1 + 0x80)) + iVar9;
    *(int *)(iVar11 + 0x18 + *(int *)(param_1 + 0x80)) =
         *(int *)(iVar11 + 0x18 + *(int *)(param_1 + 0x80)) + iVar8;
    *(int *)(iVar11 + 0x1c + *(int *)(param_1 + 0x80)) =
         *(int *)(iVar11 + 0x1c + *(int *)(param_1 + 0x80)) + iVar9;
    *(int *)(iVar11 + 0x20 + *(int *)(param_1 + 0x80)) =
         *(int *)(iVar11 + 0x20 + *(int *)(param_1 + 0x80)) + iVar8;
    *(undefined4 *)(iVar11 + 0x24 + *(int *)(param_1 + 0x80)) =
         *(undefined4 *)(iVar11 + 0x14 + *(int *)(param_1 + 0x80));
    *(undefined4 *)(iVar11 + 0x28 + *(int *)(param_1 + 0x80)) =
         *(undefined4 *)(iVar11 + 0x18 + *(int *)(param_1 + 0x80));
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
  }
  ExceptionList = local_c;
  return;
}

