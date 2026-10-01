
void __thiscall Engine_QUEST_SET_RUIN_DONE_452150(int param_1,int param_2)

{
  int *piVar1;
  int iVar2;
  undefined4 uVar3;
  int iVar4;
  int *piVar5;
  int *piVar6;
  int local_14;
  int local_10;
  int local_c;
  int local_8;
  int local_4;
  
  piVar6 = *(int **)(param_1 + 100);
  piVar1 = (int *)*piVar6;
  piVar5 = piVar1;
  if (piVar1 != piVar6) {
    while (piVar5[2] != param_2) {
      piVar5 = (int *)*piVar5;
      if (piVar5 == piVar6) {
        return;
      }
    }
    for (; piVar1 != piVar6; piVar1 = (int *)*piVar1) {
      if (piVar1[2] == param_2) {
        iVar2 = piVar1[4];
        piVar1[4] = iVar2 + -1;
        if (0 < iVar2 + -1) {
          return;
        }
        local_14 = piVar1[2];
        local_10 = piVar1[3];
        local_c = piVar1[4];
        local_8 = piVar1[5];
        local_4 = piVar1[6];
        if (piVar1 != *(int **)(param_1 + 100)) {
          *(int *)piVar1[1] = *piVar1;
          *(int *)(*piVar1 + 4) = piVar1[1];
                    /* WARNING: Subroutine does not return */
          operator_delete(piVar1);
        }
        break;
      }
    }
    local_4 = CONCAT31(local_4._1_3_,1);
    if ((2 < *(uint *)(param_1 + 0x74)) &&
       (piVar6 = (int *)**(int **)(param_1 + 0x70), piVar6 != *(int **)(param_1 + 0x70))) {
      *(int *)piVar6[1] = *piVar6;
      *(int *)(*piVar6 + 4) = piVar6[1];
                    /* WARNING: Subroutine does not return */
      operator_delete(piVar6);
    }
    iVar2 = *(int *)(param_1 + 0x70);
    iVar4 = FUN_004504c0(iVar2,*(undefined4 *)(iVar2 + 4),&local_14);
    FUN_00450510(1);
    *(int *)(iVar2 + 4) = iVar4;
    **(int **)(iVar4 + 4) = iVar4;
    uVar3 = DAT_0057f484;
    if (DAT_005af27c != '\0') {
      FUN_0045adc0();
      FUN_0045af90();
      piVar6 = (int *)**(int **)(param_1 + 0x48);
      if (piVar6 != *(int **)(param_1 + 0x48)) {
        do {
          (**(code **)(*(int *)piVar6[2] + 0xc))(*(undefined4 *)(param_1 + 0x40),uVar3,1);
          piVar6 = (int *)*piVar6;
        } while (piVar6 != (int *)*(int *)(param_1 + 0x48));
      }
    }
  }
  return;
}

