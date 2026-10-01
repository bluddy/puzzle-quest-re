
void __thiscall Engine_QUEST_SET_VISIBILITY_450e40(int param_1,int param_2,int param_3)

{
  int iVar1;
  undefined4 *puVar2;
  undefined4 *puVar3;
  int iVar4;
  int iVar5;
  int iVar6;
  undefined1 uVar7;
  int *piVar8;
  undefined4 uVar9;
  undefined4 uVar10;
  
  iVar1 = param_3;
  uVar9 = *(undefined4 *)(param_1 + 0x40);
  uVar10 = 0;
  Engine_QUEST_ABANDON_44e920(uVar9,0);
  Engine_QUEST_ABANDON_44d8e0(uVar9,uVar10);
  iVar4 = param_2;
  FUN_00442e40(param_2);
  puVar2 = (undefined4 *)FUN_00419340(iVar4);
  iVar4 = param_2;
  FUN_0045cf30(param_2);
  FUN_0045ca60(iVar4);
  iVar4 = param_2;
  FUN_004654f0(param_2);
  puVar3 = (undefined4 *)FUN_0045ca60(iVar4);
  uVar7 = (undefined1)param_3;
  if (puVar2 != (undefined4 *)0x0) {
    *(undefined1 *)(puVar2 + 0x116) = uVar7;
    uVar9 = *puVar2;
    iVar4 = Engine_QUEST_GET_CITY_STATUS_437800(uVar9);
    if (iVar4 == 0) {
      FUN_0046c9a0(uVar9,0,0,0,param_3);
    }
    else {
      *(undefined1 *)(iVar4 + 7) = uVar7;
    }
  }
  if (puVar3 != (undefined4 *)0x0) {
    uVar9 = *puVar3;
    *(undefined1 *)(puVar3 + 0x115) = uVar7;
    iVar4 = Engine_QUEST_GET_CITY_STATUS_437800(uVar9);
    if (iVar4 == 0) {
      FUN_0046c9a0(uVar9,0,0,0,param_3);
    }
    else {
      *(undefined1 *)(iVar4 + 7) = uVar7;
    }
  }
  iVar4 = 0;
  param_3 = 0;
  do {
    iVar5 = FUN_0045c160();
    uVar9 = DAT_0057f484;
    if (*(int *)(iVar5 + 8) == 0) {
      iVar5 = 0;
    }
    else {
      iVar5 = (*(int *)(iVar5 + 0xc) - *(int *)(iVar5 + 8)) / 0xc;
    }
    if (iVar5 <= param_3) {
      if (DAT_005af27c != '\0') {
        FUN_0045adc0();
        FUN_0045af90();
        piVar8 = (int *)**(int **)(param_1 + 0x48);
        if (piVar8 != *(int **)(param_1 + 0x48)) {
          do {
            (**(code **)(*(int *)piVar8[2] + 0xc))(*(undefined4 *)(param_1 + 0x40),uVar9,1);
            piVar8 = (int *)*piVar8;
          } while (piVar8 != (int *)*(int *)(param_1 + 0x48));
        }
      }
      Engine_QUEST_ADD_ITEM_4b1590();
      return;
    }
    iVar5 = FUN_0045c160();
    iVar6 = (int)*(char *)(*(int *)(iVar5 + 8) + 8 + iVar4);
    piVar8 = (int *)(*(int *)(iVar5 + 8) + iVar4);
    if (iVar6 != iVar1) {
      if (*piVar8 == param_2) {
        iVar5 = 1;
      }
      else {
        if ((iVar6 == iVar1) || (piVar8[1] != param_2)) goto LAB_00450fb0;
        iVar5 = 0;
      }
      iVar5 = piVar8[iVar5];
      iVar6 = iVar5;
      FUN_00442e40(iVar5);
      iVar6 = FUN_00419340(iVar6);
      FUN_004654f0(iVar5);
      iVar5 = FUN_0045ca60(iVar5);
      if (iVar1 == 0) {
        *(undefined1 *)(piVar8 + 2) = 0;
      }
      else if (((iVar6 != 0) && (*(char *)(iVar6 + 0x458) != '\0')) ||
              ((iVar5 != 0 && (*(char *)(iVar5 + 0x454) != '\0')))) {
        *(undefined1 *)(piVar8 + 2) = 1;
      }
    }
LAB_00450fb0:
    param_3 = param_3 + 1;
    iVar4 = iVar4 + 0xc;
  } while( true );
}

