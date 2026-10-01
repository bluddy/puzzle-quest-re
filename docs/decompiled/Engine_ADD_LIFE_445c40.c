
void __thiscall Engine_ADD_LIFE_445c40(int param_1,int param_2)

{
  int iVar1;
  int iVar2;
  
  iVar2 = param_1 + 0x48;
  iVar1 = iVar2;
  FUN_00445030(iVar2);
  FUN_00444d40(iVar1);
  param_2 = *(int *)(param_1 + 0x70) + param_2;
  if (*(int *)(param_1 + 100) <= param_2) {
    param_2 = *(int *)(param_1 + 100);
  }
  *(int *)(param_1 + 0x70) = param_2;
  FUN_00445030(iVar2);
  FUN_00444d80(iVar2);
  return;
}

