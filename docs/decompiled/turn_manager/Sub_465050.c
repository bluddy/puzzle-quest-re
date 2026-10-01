
void FUN_00465050(undefined4 *param_1,undefined4 *param_2,undefined4 *param_3)

{
  int iVar1;
  undefined4 *puVar2;
  undefined4 *puVar3;
  
  if (param_1 != param_2) {
    do {
      param_2 = param_2 + -0x116;
      param_3 = param_3 + -0x116;
      puVar2 = param_2;
      puVar3 = param_3;
      for (iVar1 = 0x116; iVar1 != 0; iVar1 = iVar1 + -1) {
        *puVar3 = *puVar2;
        puVar2 = puVar2 + 1;
        puVar3 = puVar3 + 1;
      }
    } while (param_2 != param_1);
  }
  return;
}

