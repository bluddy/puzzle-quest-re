
void __thiscall Engine_SET_MANA_AIR_445c00(int param_1,int param_2,int param_3)

{
  int iVar1;
  int iVar2;
  
  iVar2 = param_1 + 0x48;
  iVar1 = iVar2;
  Engine_ADD_MAX_LIFE_445030(iVar2);
  Engine_ADD_MAX_LIFE_444d40(iVar1);
  iVar1 = *(int *)(param_1 + 0x84 + param_2 * 4);
  if (param_3 < iVar1) {
    iVar1 = param_3;
  }
  *(int *)(param_1 + 0x74 + param_2 * 4) = iVar1;
  Engine_ADD_MAX_LIFE_445030(iVar2);
  Engine_ADD_MAX_LIFE_444d80(iVar2);
  return;
}

