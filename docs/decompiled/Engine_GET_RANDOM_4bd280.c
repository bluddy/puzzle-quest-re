
void Engine_GET_RANDOM_4bd280(int param_1,int param_2)

{
  int iVar1;
  uint uVar2;
  
  iVar1 = param_1;
  if (param_2 <= param_1) {
    iVar1 = param_2;
  }
  uVar2 = param_2 - param_1 >> 0x1f;
  FUN_004bd1f0(1,((param_2 - param_1 ^ uVar2) - uVar2) + 1,iVar1 + -1);
  return;
}

