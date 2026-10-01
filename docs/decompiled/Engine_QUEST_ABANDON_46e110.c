
void __thiscall Engine_QUEST_ABANDON_46e110(int param_1,int param_2)

{
  int iVar1;
  undefined4 *puVar2;
  int *piVar3;
  undefined4 uVar4;
  
  iVar1 = 0;
  if (0 < *(int *)(param_1 + 0x1cc)) {
    piVar3 = (int *)(param_1 + 0x1d0);
    do {
      if (*piVar3 == param_2) {
        if (-1 < iVar1) {
          if (iVar1 < *(int *)(param_1 + 0x1cc) + -1) {
            puVar2 = (undefined4 *)(param_1 + 0x1d0 + iVar1 * 6);
            do {
              *puVar2 = *(undefined4 *)((int)puVar2 + 6);
              *(undefined2 *)(puVar2 + 1) = *(undefined2 *)((int)puVar2 + 10);
              iVar1 = iVar1 + 1;
              puVar2 = (undefined4 *)((int)puVar2 + 6);
            } while (iVar1 < *(int *)(param_1 + 0x1cc) + -1);
          }
          *(int *)(param_1 + 0x1cc) = *(int *)(param_1 + 0x1cc) + -1;
        }
        break;
      }
      iVar1 = iVar1 + 1;
      piVar3 = (int *)((int)piVar3 + 6);
    } while (iVar1 < *(int *)(param_1 + 0x1cc));
  }
  iVar1 = param_2;
  FUN_0045adc0(param_2);
  iVar1 = FUN_00403540(iVar1);
  if (iVar1 != 0) {
    FUN_004730f0(3,0,0,0);
    FUN_00472e00();
  }
  FUN_0046c690(param_2,0);
  uVar4 = 1;
  Engine_QUEST_ENCOUNTER_ADD_4556f0(1);
  FUN_004507a0(uVar4);
  *(undefined1 *)(param_1 + 0xbc) = 1;
  return;
}

