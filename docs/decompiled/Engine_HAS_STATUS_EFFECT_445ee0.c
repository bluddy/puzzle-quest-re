
uint __thiscall Engine_HAS_STATUS_EFFECT_445ee0(int param_1,int param_2,int param_3)

{
  uint uVar1;
  int iVar2;
  int iVar3;
  int iVar4;
  
  iVar4 = 0;
  while( true ) {
    iVar3 = *(int *)(*(int *)(param_1 + 8) + 0x5c + param_2 * 0xa8);
    uVar1 = *(int *)(param_1 + 8) + param_2 * 0xa8;
    if (iVar3 == 0) {
      iVar3 = 0;
    }
    else {
      iVar3 = *(int *)(uVar1 + 0x60) - iVar3 >> 3;
    }
    if (iVar3 <= iVar4) break;
    iVar3 = *(int *)(*(int *)(uVar1 + 0x5c) + iVar4 * 8);
    iVar2 = Engine_GET_STATUS_EFFECT_ON_PLAYER_464430();
    iVar3 = *(int *)(iVar3 * 0x44 + 4 + *(int *)(iVar2 + 8));
    if (iVar3 == param_3) {
      return CONCAT31((int3)((uint)iVar3 >> 8),1);
    }
    iVar4 = iVar4 + 1;
  }
  return uVar1 & 0xffffff00;
}

