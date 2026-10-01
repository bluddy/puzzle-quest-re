
char FUN_0043fcb0(undefined4 param_1,undefined4 param_2,undefined4 param_3,undefined4 param_4)

{
  char cVar1;
  char cVar2;
  int iVar3;
  int iVar4;
  undefined1 local_128 [296];
  
  FUN_0043fc10();
  cVar2 = '\0';
  Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
  CBoard_SwapGems_47b280(param_1,param_2,param_3,param_4);
  iVar3 = 1;
  do {
    if (cVar2 != '\0') break;
    iVar4 = 0;
    do {
      if (cVar2 != '\0') break;
      cVar1 = CBoard_CheckMatch_47c8c0(iVar4,iVar3,1,local_128);
      if (cVar1 != '\0') {
        cVar2 = '\x01';
      }
      cVar1 = CBoard_CheckMatch_47c8c0(iVar4,iVar3,0,local_128);
      if (cVar1 != '\0') {
        cVar2 = '\x01';
      }
      iVar4 = iVar4 + 1;
    } while (iVar4 < 8);
    iVar3 = iVar3 + 1;
  } while (iVar3 < 9);
  CBoard_SwapGems_47b280(param_1,param_2,param_3,param_4);
  return cVar2;
}

