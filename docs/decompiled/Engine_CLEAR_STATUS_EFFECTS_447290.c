
void __thiscall Engine_CLEAR_STATUS_EFFECTS_447290(int param_1,int param_2)

{
  void *pvVar1;
  int iVar2;
  
  param_2 = param_2 * 0xa8;
  pvVar1 = *(void **)(*(int *)(param_1 + 8) + 0x5c + param_2);
  iVar2 = *(int *)(param_1 + 8) + param_2;
  if (pvVar1 != (void *)0x0) {
                    /* WARNING: Subroutine does not return */
    operator_delete(pvVar1);
  }
  *(undefined4 *)(iVar2 + 0x5c) = 0;
  *(undefined4 *)(iVar2 + 0x60) = 0;
  *(undefined4 *)(iVar2 + 100) = 0;
  *(undefined1 *)(*(int *)(param_1 + 8) + param_2 + 0x14) = 1;
  return;
}

