
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void __thiscall Engine_QUEST_CUTSCENE_4aa0d0(int param_1,undefined1 param_2,undefined4 param_3)

{
  void *pvVar1;
  char cVar2;
  int iVar3;
  undefined4 uVar4;
  float10 fVar5;
  float fVar6;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  pvVar1 = ExceptionList;
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00516c63;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  *(undefined1 *)(param_1 + 0x3540) = param_2;
  *(undefined4 *)(param_1 + 0x3544) = param_3;
  if (DAT_0059a4b9 == '\0') {
    if (*(int *)(param_1 + 0x494) != 0) {
      *(undefined1 *)(param_1 + 0x352c) = 1;
      DAT_005872e4 = 1;
      ExceptionList = pvVar1;
      return;
    }
  }
  else {
    *(undefined1 *)(param_1 + 0x3508) = 0;
    iVar3 = FUN_004f0184(0x70);
    local_4 = 0;
    if (iVar3 == 0) {
      uVar4 = 0;
    }
    else {
      uVar4 = FUN_004ad2f0();
    }
    local_4 = 0xffffffff;
    *(undefined4 *)(param_1 + 0x3524) = uVar4;
    uVar4 = Engine_ACTIVATE_COMPANION_4be530(param_1 + 4,0xffffffff);
    local_4 = 1;
    FUN_004acd40();
    Engine_QUEST_COMPANION_MESSAGE_CALLBACK_4becb0(uVar4);
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    FUN_004ace80();
    if (*(int *)(param_1 + 0x3528) != 0) {
      FUN_004b1830();
    }
    FUN_004aa800();
    if (*(int *)(param_1 + 0x3504) < 1) {
      *(undefined1 *)(param_1 + 0x3508) = 1;
      if (*(int **)(param_1 + 0x3528) != (int *)0x0) {
        (**(code **)(**(int **)(param_1 + 0x3528) + 0x28))();
        (**(code **)(**(int **)(param_1 + 0x3528) + 0x30))(0x3f800000);
      }
    }
    *(undefined1 *)(param_1 + 0x352d) = 0;
    FUN_004d0d50();
    cVar2 = FUN_004cec80();
    if ((cVar2 != '\0') && (*(int *)(param_1 + 0x3528) != 0)) {
      *(undefined1 *)(param_1 + 0x352d) = 1;
      FUN_004d0d50();
      fVar5 = (float10)FUN_004cec60();
      *(float *)(param_1 + 0x3530) = (float)fVar5;
      fVar6 = (float)(fVar5 * (float10)_DAT_00529d48);
      FUN_004d0d50(fVar6);
      FUN_004cec00(fVar6);
    }
    *(undefined4 *)(param_1 + 0x3538) = 0xffffffff;
    *(undefined4 *)(param_1 + 0x3534) = 0;
    *(undefined4 *)(param_1 + 0x353c) = DAT_0057f484;
    *(undefined1 *)(param_1 + 0x352c) = 0;
    DAT_005872e4 = 1;
    *(undefined1 *)(param_1 + 0x3520) = 1;
    *(undefined4 *)(param_1 + 0x34fc) = DAT_0057f484;
    DAT_005872e5 = 0;
  }
  ExceptionList = local_c;
  return;
}

