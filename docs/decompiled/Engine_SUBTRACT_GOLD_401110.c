
void __thiscall Engine_SUBTRACT_GOLD_401110(int param_1,int param_2)

{
  uint uVar1;
  int iVar2;
  int iVar3;
  
  iVar3 = param_1 + 0x48;
  iVar2 = iVar3;
  Engine_ADD_MAX_LIFE_445030(iVar3);
  Engine_ADD_MAX_LIFE_444d40(iVar2);
  uVar1 = *(int *)(param_1 + 0x94) - param_2;
  *(uint *)(param_1 + 0x94) = uVar1 & ((int)uVar1 < 1) - 1;
  Engine_ADD_MAX_LIFE_445030(iVar3);
  Engine_ADD_MAX_LIFE_444d80(iVar3);
  *(undefined1 *)(param_1 + 0xbc) = 1;
  return;
}

