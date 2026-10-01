
void __thiscall FUN_0047b280(int param_1,int param_2,int param_3,int param_4,int param_5)

{
  undefined4 *puVar1;
  undefined4 *puVar2;
  undefined4 uVar3;
  undefined4 uVar4;
  
  puVar1 = (undefined4 *)(param_1 + 4 + param_3 * 8 + param_2 * 0x48);
  param_5 = param_5 + param_4 * 9;
  puVar2 = (undefined4 *)(param_1 + 4 + param_5 * 8);
  uVar3 = *puVar1;
  uVar4 = puVar1[1];
  *puVar1 = *(undefined4 *)(param_1 + 4 + param_5 * 8);
  puVar1[1] = puVar2[1];
  puVar2[1] = uVar4;
  *puVar2 = uVar3;
  return;
}

