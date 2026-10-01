
void __thiscall Engine_ADD_MANA_AIR_47a660(int *param_1,int param_2,undefined4 param_3)

{
  int iVar1;
  int iVar2;
  int *piVar3;
  int *piVar4;
  
  iVar1 = (**(code **)(*param_1 + 0x20))(0xd,param_3,param_1[0x11],param_2);
  piVar4 = param_1 + 0x12;
  piVar3 = piVar4;
  FUN_00445030(piVar4);
  FUN_00444d40(piVar3);
  iVar2 = param_1[param_2 + 0x1d] + iVar1;
  if (param_1[param_2 + 0x21] <= param_1[param_2 + 0x1d] + iVar1) {
    iVar2 = param_1[param_2 + 0x21];
  }
  param_1[param_2 + 0x1d] = iVar2;
  FUN_00445030(piVar4);
  FUN_00444d80(piVar4);
  return;
}

