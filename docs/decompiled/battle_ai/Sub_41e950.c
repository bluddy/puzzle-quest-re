
void FUN_0041e950(int param_1,undefined4 param_2,undefined4 param_3,int param_4)

{
  int iVar1;
  int iVar2;
  int iVar3;
  int iVar4;
  int iVar5;
  
  FUN_0041e880(param_1,param_2,param_3,param_4);
  param_4 = 0;
  iVar2 = 8;
  do {
    iVar3 = 1;
    iVar4 = iVar2;
    do {
      iVar1 = Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
      iVar1 = *(int *)(iVar4 + 4 + iVar1);
      if ((iVar1 == param_1) || ((iVar1 == 0xf && (param_1 == 5)))) {
        iVar1 = param_4;
        iVar5 = iVar3;
        Engine_ADD_ANIMEFFECT_TO_GRID_47a820(param_4,iVar3);
        Engine_DESTROY_GEM_47e000(iVar1,iVar5);
      }
      iVar3 = iVar3 + 1;
      iVar4 = iVar4 + 8;
    } while (iVar3 < 9);
    param_4 = param_4 + 1;
    iVar2 = iVar2 + 0x48;
  } while (iVar2 < 0x248);
  return;
}

