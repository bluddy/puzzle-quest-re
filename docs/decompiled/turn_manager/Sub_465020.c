
void FUN_00465020(undefined4 *param_1,undefined4 *param_2,undefined4 *param_3)

{
  undefined4 *puVar1;
  int iVar2;
  undefined4 *puVar3;
  
  if (param_1 != param_2) {
    do {
      puVar1 = param_1 + 0x116;
      puVar3 = param_3;
      for (iVar2 = 0x116; iVar2 != 0; iVar2 = iVar2 + -1) {
        *param_1 = *puVar3;
        puVar3 = puVar3 + 1;
        param_1 = param_1 + 1;
      }
      param_1 = puVar1;
    } while (puVar1 != param_2);
  }
  return;
}

