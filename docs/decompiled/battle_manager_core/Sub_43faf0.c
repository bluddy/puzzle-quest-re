
undefined4 __fastcall FUN_0043faf0(int param_1)

{
  int iVar1;
  int iVar2;
  int iVar3;
  int iVar4;
  
  if (*(char *)(param_1 + 0x2c) == '\0') {
    return 0;
  }
  iVar2 = *(int *)(param_1 + 0x34);
  iVar1 = *(int *)(param_1 + 0x30);
  if (*(char *)(param_1 + 0x38) != '\0') {
    iVar3 = iVar1 + 1;
    iVar4 = iVar2;
    Engine_ADD_ANIMEFFECT_TO_GRID_47a820(iVar1,iVar2,iVar3,iVar2);
    FUN_0047dc30(iVar1,iVar2,iVar3,iVar4);
    return 1;
  }
  iVar3 = iVar2 + 1;
  iVar4 = iVar1;
  Engine_ADD_ANIMEFFECT_TO_GRID_47a820(iVar1,iVar2,iVar1,iVar3);
  FUN_0047dc30(iVar1,iVar2,iVar4,iVar3);
  return 1;
}

