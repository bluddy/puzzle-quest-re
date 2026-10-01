
void __thiscall Engine_QUEST_MOVE_44c750(int param_1,undefined4 param_2)

{
  int *piVar1;
  undefined4 uVar2;
  int iVar3;
  int iVar4;
  
  uVar2 = *(undefined4 *)(param_1 + 0xc);
  Engine_QUEST_ENCOUNTER_ADD_4556f0();
  iVar3 = FUN_00455ca0(uVar2,param_2,(int *)(param_1 + 0x2c));
  *(int *)(param_1 + 0x22c) = iVar3;
  if (0 < iVar3) {
    *(undefined4 *)(param_1 + 0x1c) = *(undefined4 *)(param_1 + 0xc);
    *(undefined4 *)(param_1 + 0x20) = param_2;
    *(undefined4 *)(param_1 + 0x230) = 0;
    iVar3 = *(int *)(param_1 + 0x2c);
    iVar4 = FUN_0045c160();
    piVar1 = (int *)(*(int *)(iVar4 + 8) + iVar3 * 0xc);
    iVar3 = *piVar1;
    if (*(int *)(param_1 + 0xc) == iVar3) {
      iVar3 = piVar1[1];
    }
    *(int *)(param_1 + 0x10) = iVar3;
    FUN_0044c360(*(undefined4 *)(param_1 + 0x230));
  }
  return;
}

