
void __thiscall Engine_ADD_TEMP_SKILL_445c80(int param_1,int param_2)

{
  int iVar1;
  int iVar2;
  
  iVar2 = param_1 + 0x48;
  iVar1 = iVar2;
  Engine_ADD_MAX_LIFE_445030(iVar2);
  Engine_ADD_MAX_LIFE_444d40(iVar1);
  *(int *)(param_1 + 100) = *(int *)(param_1 + 100) + param_2;
  Engine_ADD_MAX_LIFE_445030(iVar2);
  Engine_ADD_MAX_LIFE_444d80(iVar2);
  return;
}

