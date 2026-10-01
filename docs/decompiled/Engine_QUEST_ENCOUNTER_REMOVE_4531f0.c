
void __thiscall Engine_QUEST_ENCOUNTER_REMOVE_4531f0(int param_1,int param_2)

{
  undefined4 *puVar1;
  undefined4 uVar2;
  char cVar3;
  int iVar4;
  int iVar5;
  int iVar6;
  int *piVar7;
  
  cVar3 = FUN_00451110(param_2);
  if (cVar3 != '\0') {
    iVar5 = 0;
    while( true ) {
      if (*(int *)(param_1 + 0x7c) == 0) {
        iVar4 = 0;
      }
      else {
        iVar4 = *(int *)(param_1 + 0x80) - *(int *)(param_1 + 0x7c) >> 2;
      }
      iVar6 = -1;
      if ((iVar4 <= iVar5) ||
         (iVar6 = iVar5, *(int *)(*(int *)(param_1 + 0x7c) + iVar5 * 4) == param_2)) break;
      iVar5 = iVar5 + 1;
    }
    while( true ) {
      if (*(int *)(param_1 + 0x7c) == 0) {
        iVar5 = 0;
      }
      else {
        iVar5 = *(int *)(param_1 + 0x80) - *(int *)(param_1 + 0x7c) >> 2;
      }
      if (iVar5 + -1 <= iVar6) break;
      puVar1 = (undefined4 *)(*(int *)(param_1 + 0x7c) + iVar6 * 4);
      *puVar1 = puVar1[1];
      iVar6 = iVar6 + 1;
    }
    if ((*(int *)(param_1 + 0x7c) != 0) &&
       (*(int *)(param_1 + 0x80) - *(int *)(param_1 + 0x7c) >> 2 != 0)) {
      *(int *)(param_1 + 0x80) = *(int *)(param_1 + 0x80) + -4;
    }
    uVar2 = DAT_0057f484;
    if (DAT_005af27c != '\0') {
      FUN_0045adc0();
      FUN_0045af90();
      piVar7 = (int *)**(int **)(param_1 + 0x48);
      if (piVar7 != *(int **)(param_1 + 0x48)) {
        do {
          (**(code **)(*(int *)piVar7[2] + 0xc))(*(undefined4 *)(param_1 + 0x40),uVar2,1);
          piVar7 = (int *)*piVar7;
        } while (piVar7 != (int *)*(int *)(param_1 + 0x48));
      }
    }
  }
  return;
}

