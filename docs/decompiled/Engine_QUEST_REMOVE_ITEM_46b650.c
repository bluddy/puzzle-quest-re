
void __thiscall Engine_QUEST_REMOVE_ITEM_46b650(int param_1,int param_2)

{
  int iVar1;
  char cVar2;
  int iVar3;
  int iVar4;
  undefined4 *puVar5;
  int extraout_ECX;
  int extraout_ECX_00;
  int iVar6;
  int iVar7;
  
  iVar6 = 0;
  iVar7 = 0;
  while( true ) {
    if (*(int *)(param_1 + 0xf8) == 0) {
      iVar3 = 0;
    }
    else {
      iVar3 = (*(int *)(param_1 + 0xfc) - *(int *)(param_1 + 0xf8)) / 5;
    }
    if (iVar3 <= iVar6) {
      return;
    }
    if (*(int *)(*(int *)(param_1 + 0xf8) + iVar7) == param_2) break;
    iVar6 = iVar6 + 1;
    iVar7 = iVar7 + 5;
  }
  cVar2 = FUN_00468750(param_2);
  iVar6 = extraout_ECX;
  if (cVar2 != '\0') {
    FUN_004687c0(param_2);
    iVar6 = extraout_ECX_00;
  }
  iVar3 = 0;
  iVar7 = 0;
  while( true ) {
    if (*(int *)(iVar6 + 0xf8) == 0) {
      iVar4 = 0;
    }
    else {
      iVar4 = (*(int *)(iVar6 + 0xfc) - *(int *)(iVar6 + 0xf8)) / 5;
    }
    if (iVar4 <= iVar3) goto LAB_0046b770;
    if (*(int *)(*(int *)(iVar6 + 0xf8) + iVar7) == param_2) break;
    iVar3 = iVar3 + 1;
    iVar7 = iVar7 + 5;
  }
  iVar7 = iVar3 * 5;
  while( true ) {
    iVar4 = *(int *)(iVar6 + 0xf8);
    if (iVar4 != 0) {
      iVar4 = (*(int *)(iVar6 + 0xfc) - iVar4) / 5;
    }
    iVar1 = *(int *)(iVar6 + 0xf8);
    if (iVar4 + -1 <= iVar3) break;
    puVar5 = (undefined4 *)(iVar1 + iVar7);
    *puVar5 = *(undefined4 *)(iVar1 + 5 + iVar7);
    iVar3 = iVar3 + 1;
    *(undefined1 *)(puVar5 + 1) = *(undefined1 *)((int)puVar5 + 9);
    iVar7 = iVar7 + 5;
  }
  if ((iVar1 != 0) && ((*(int *)(iVar6 + 0xfc) - iVar1) / 5 != 0)) {
    *(int *)(iVar6 + 0xfc) = *(int *)(iVar6 + 0xfc) + -5;
  }
LAB_0046b770:
  *(undefined1 *)(iVar6 + 0xbc) = 1;
  return;
}

