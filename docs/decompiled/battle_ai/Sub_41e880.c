
void __thiscall FUN_0041e880(int param_1,undefined4 param_2,int param_3,int param_4,char param_5)

{
  int iVar1;
  int iVar2;
  int iVar3;
  int iVar4;
  
  iVar2 = 0;
  iVar4 = 8;
  if (param_5 == '\0') {
    iVar3 = param_3 * 0x48;
    do {
      iVar1 = Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
      if (*(int *)(iVar3 + 0xc + iVar1) == 0x11) {
        iVar2 = iVar2 + 1;
      }
      iVar4 = iVar4 + -1;
      iVar3 = iVar3 + 8;
    } while (iVar4 != 0);
  }
  else {
    iVar3 = param_4 << 3;
    do {
      iVar1 = Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
      if (*(int *)(iVar3 + 4 + iVar1) == 0x11) {
        iVar2 = iVar2 + 1;
      }
      iVar3 = iVar3 + 0x48;
      iVar4 = iVar4 + -1;
    } while (iVar4 != 0);
  }
  if (1 < iVar2) {
    iVar2 = *(int *)(param_1 + 0x70) + iVar2 + -1;
    *(int *)(param_1 + 0x70) = iVar2;
    if (*(int *)(param_1 + 0x74) < iVar2) {
      *(int *)(param_1 + 0x70) = *(int *)(param_1 + 0x74);
    }
  }
  if (param_5 == '\0') {
    iVar2 = 1;
    do {
      iVar4 = param_3;
      iVar3 = iVar2;
      Engine_ADD_ANIMEFFECT_TO_GRID_47a820(param_3,iVar2);
      Engine_DESTROY_GEM_47e000(iVar4,iVar3);
      iVar2 = iVar2 + 1;
    } while (iVar2 < 9);
    return;
  }
  iVar2 = 0;
  do {
    iVar4 = iVar2;
    iVar3 = param_4;
    Engine_ADD_ANIMEFFECT_TO_GRID_47a820(iVar2,param_4);
    Engine_DESTROY_GEM_47e000(iVar4,iVar3);
    iVar2 = iVar2 + 1;
  } while (iVar2 < 8);
  return;
}

