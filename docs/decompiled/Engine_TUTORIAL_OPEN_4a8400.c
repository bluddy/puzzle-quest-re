
void __thiscall Engine_TUTORIAL_OPEN_4a8400(int param_1,undefined4 param_2)

{
  char cVar1;
  int iVar2;
  int iVar3;
  undefined1 auStack_18 [12];
  void *pvStack_c;
  undefined1 *puStack_8;
  undefined4 uStack_4;
  
  uStack_4 = 0xffffffff;
  puStack_8 = &LAB_00516a88;
  pvStack_c = ExceptionList;
  ExceptionList = &pvStack_c;
  if (*(int *)(param_1 + 0x18) != 0) {
    ExceptionList = &pvStack_c;
    thunk_FUN_004a89d0();
    *(undefined4 *)(param_1 + 0x18) = 0;
  }
  iVar2 = FUN_004a7b40(param_2);
  *(int *)(param_1 + 0x18) = iVar2;
  if (iVar2 != 0) {
    if ((*(int *)(iVar2 + 0x40) != 0) || (*(int *)(iVar2 + 0x44) != 1)) {
LAB_004a84d5:
      FUN_004a7360();
      ExceptionList = pvStack_c;
      return;
    }
    iVar2 = 0;
    while( true ) {
      if (DAT_00586088 == 0) {
        iVar3 = 0;
      }
      else {
        iVar3 = (DAT_0058608c - DAT_00586088) / 0xc;
      }
      if (iVar3 <= iVar2) {
        Engine_ACTIVATE_COMPANION_4be530(param_2,0xffffffff);
        uStack_4 = 0;
        FUN_00409d40(auStack_18);
        uStack_4 = 0xffffffff;
        Engine_ACTIVATE_COMPANION_4bdf40();
        goto LAB_004a84d5;
      }
      cVar1 = FUN_004bddd0(param_2);
      if (cVar1 != '\0') break;
      iVar2 = iVar2 + 1;
    }
    *(undefined4 *)(param_1 + 0x18) = 0;
  }
  ExceptionList = pvStack_c;
  return;
}

