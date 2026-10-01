
void __thiscall Engine_QUEST_ADD_RUIN_452010(int param_1,int param_2)

{
  undefined4 *puVar1;
  undefined4 uVar2;
  int iVar3;
  int iVar4;
  int *piVar5;
  int local_14;
  int local_10;
  undefined4 local_c;
  undefined4 local_8;
  undefined1 local_4;
  
  for (puVar1 = (undefined4 *)**(undefined4 **)(param_1 + 100);
      puVar1 != *(undefined4 **)(param_1 + 100); puVar1 = (undefined4 *)*puVar1) {
    if (puVar1[2] == param_2) {
      puVar1[4] = puVar1[4] + 1;
      goto LAB_004520cd;
    }
  }
  local_14 = param_2;
  iVar4 = param_2;
  FUN_0045cf30(param_2);
  local_10 = FUN_0045cad0(iVar4);
  if (local_10 != -1) {
    iVar4 = *(int *)(param_1 + 100);
    local_4 = 0;
    local_8 = 0xffffffff;
    local_c = 1;
    iVar3 = FUN_004504c0(iVar4,*(undefined4 *)(iVar4 + 4),&local_14);
    FUN_00450510(1);
    *(int *)(iVar4 + 4) = iVar3;
    **(int **)(iVar3 + 4) = iVar3;
    iVar4 = local_10;
    FUN_0045cf30(local_10);
    iVar4 = FUN_0045ca40(iVar4);
    iVar4 = FUN_00450650(param_2,*(undefined4 *)(iVar4 + 0x454));
    if (iVar4 != 0) {
      *(undefined1 *)(iVar4 + 10) = 1;
    }
LAB_004520cd:
    uVar2 = DAT_0057f484;
    for (piVar5 = (int *)**(int **)(param_1 + 0x70); piVar5 != *(int **)(param_1 + 0x70);
        piVar5 = (int *)*piVar5) {
      if (piVar5[2] == param_2) {
        if (piVar5 != *(int **)(param_1 + 0x70)) {
          *(int *)piVar5[1] = *piVar5;
          *(int *)(*piVar5 + 4) = piVar5[1];
                    /* WARNING: Subroutine does not return */
          operator_delete(piVar5);
        }
        break;
      }
    }
    if (DAT_005af27c != '\0') {
      FUN_0045adc0();
      FUN_0045af90();
      piVar5 = (int *)**(int **)(param_1 + 0x48);
      if (piVar5 != *(int **)(param_1 + 0x48)) {
        do {
          (**(code **)(*(int *)piVar5[2] + 0xc))(*(undefined4 *)(param_1 + 0x40),uVar2,1);
          piVar5 = (int *)*piVar5;
        } while (piVar5 != (int *)*(int *)(param_1 + 0x48));
      }
    }
  }
  return;
}

