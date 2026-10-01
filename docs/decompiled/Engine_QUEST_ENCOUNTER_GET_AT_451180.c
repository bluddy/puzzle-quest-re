
int __thiscall Engine_QUEST_ENCOUNTER_GET_AT_451180(int param_1,int param_2,int param_3)

{
  int iVar1;
  int iVar2;
  undefined4 uVar3;
  
  iVar2 = 0;
  do {
    if (*(int *)(param_1 + 0x7c) == 0) {
      iVar1 = 0;
    }
    else {
      iVar1 = *(int *)(param_1 + 0x80) - *(int *)(param_1 + 0x7c) >> 2;
    }
    if (iVar1 <= iVar2) {
      return 0;
    }
    uVar3 = *(undefined4 *)(*(int *)(param_1 + 0x7c) + iVar2 * 4);
    FUN_00445950(uVar3);
    iVar1 = FUN_00423350(uVar3);
    if (iVar1 != 0) {
      if ((*(int *)(iVar1 + 0xc) == param_2) && (*(int *)(iVar1 + 0x10) == param_3)) {
        return iVar1;
      }
      if ((*(int *)(iVar1 + 0xc) == param_3) && (*(int *)(iVar1 + 0x10) == param_2)) {
        return iVar1;
      }
    }
    iVar2 = iVar2 + 1;
  } while( true );
}

