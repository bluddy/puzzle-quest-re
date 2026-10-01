
void __thiscall Engine_SET_ITEM_447da0(int param_1,int param_2,undefined4 param_3)

{
  int iVar1;
  int iVar2;
  
  iVar2 = param_1 + 0x48;
  iVar1 = iVar2;
  Engine_ADD_MAX_LIFE_445030(iVar2);
  Engine_ADD_MAX_LIFE_444d40(iVar1);
  *(undefined4 *)(param_1 + 0x9c + param_2 * 4) = param_3;
  Engine_ADD_MAX_LIFE_445030(iVar2);
  Engine_ADD_MAX_LIFE_444d80(iVar2);
  *(undefined1 *)(param_1 + 0xbc) = 1;
  return;
}

