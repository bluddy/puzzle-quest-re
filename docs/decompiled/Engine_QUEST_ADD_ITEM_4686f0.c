
uint __thiscall Engine_QUEST_ADD_ITEM_4686f0(int param_1,int param_2)

{
  uint uVar1;
  int iVar2;
  int iVar3;
  
  iVar2 = 0;
  iVar3 = 0;
  while( true ) {
    if (*(int *)(param_1 + 0xf8) == 0) {
      uVar1 = 0;
    }
    else {
      uVar1 = (*(int *)(param_1 + 0xfc) - *(int *)(param_1 + 0xf8)) / 5;
    }
    if ((int)uVar1 <= iVar2) break;
    if (*(int *)(*(int *)(param_1 + 0xf8) + iVar3) == param_2) {
      return CONCAT31((int3)((uint)(*(int *)(param_1 + 0xf8) + iVar3) >> 8),1);
    }
    iVar2 = iVar2 + 1;
    iVar3 = iVar3 + 5;
  }
  return uVar1 & 0xffffff00;
}

