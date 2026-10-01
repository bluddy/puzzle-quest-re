
void FUN_0043fdc0(undefined4 *param_1,undefined4 *param_2,undefined4 *param_3)

{
  int iVar1;
  undefined4 *puVar2;
  undefined4 *puVar3;
  
  if (param_1 != param_2) {
    do {
      if (param_3 != (undefined4 *)0x0) {
        puVar2 = param_1;
        puVar3 = param_3;
        for (iVar1 = 0x52; iVar1 != 0; iVar1 = iVar1 + -1) {
          *puVar3 = *puVar2;
          puVar2 = puVar2 + 1;
          puVar3 = puVar3 + 1;
        }
      }
      param_1 = param_1 + 0x52;
      param_3 = param_3 + 0x52;
    } while (param_1 != param_2);
  }
  return;
}

