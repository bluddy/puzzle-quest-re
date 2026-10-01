
int __thiscall Engine_GET_TEXT_4b4050(int param_1,int param_2)

{
  int iVar1;
  char cVar2;
  
  iVar1 = param_2;
  cVar2 = FUN_004b3fa0(param_2,&param_2);
  if (cVar2 != '\0') {
    return *(int *)(*(int *)(param_1 + 4) + param_2 * 4) + 0xc;
  }
  return iVar1;
}

