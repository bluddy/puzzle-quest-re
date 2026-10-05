
void FUN_004c8f30(undefined4 *param_1,int param_2,undefined4 *param_3)

{
  int iVar1;
  
  if (param_2 != 0) {
    do {
      if (param_1 != (undefined4 *)0x0) {
        *param_1 = *param_3;
        iVar1 = param_3[1];
        param_1[1] = iVar1;
        if (iVar1 != 0) {
          LOCK();
          *(int *)(iVar1 + 4) = *(int *)(iVar1 + 4) + 1;
          UNLOCK();
        }
      }
      param_1 = param_1 + 2;
      param_2 = param_2 + -1;
    } while (param_2 != 0);
  }
  return;
}

