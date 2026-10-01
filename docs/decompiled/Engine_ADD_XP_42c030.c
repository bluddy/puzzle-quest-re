
void __thiscall Engine_ADD_XP_42c030(int *param_1,undefined4 param_2)

{
  int iVar1;
  int iVar2;
  int *piVar3;
  int *piVar4;
  
  iVar2 = (**(code **)(*param_1 + 0x20))(0xf,param_2,param_1[0x11],0);
  piVar4 = param_1 + 0x12;
  piVar3 = piVar4;
  Engine_ADD_MAX_LIFE_445030(piVar4);
  Engine_ADD_MAX_LIFE_444d40(piVar3);
  iVar1 = param_1[0x1b];
  param_1[0x1b] = iVar1 + iVar2;
  if (99999 < iVar1 + iVar2) {
    param_1[0x1b] = 99999;
  }
  Engine_ADD_MAX_LIFE_445030(piVar4);
  Engine_ADD_MAX_LIFE_444d80(piVar4);
  *(undefined1 *)(param_1 + 0x2f) = 1;
  return;
}

