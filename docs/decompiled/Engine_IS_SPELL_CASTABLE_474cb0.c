
void __fastcall Engine_IS_SPELL_CASTABLE_474cb0(int param_1)

{
  int iVar1;
  
  iVar1 = FUN_00468680(*(undefined4 *)(param_1 + 4));
  if ((iVar1 == 0) || (*(int *)(iVar1 + 8) != 0)) {
    *(short *)(param_1 + 0x2c) = *(short *)(param_1 + 0x2c) / 2 + *(short *)(param_1 + 0x2c);
    *(short *)(param_1 + 0x2e) = *(short *)(param_1 + 0x2e) / 2 + *(short *)(param_1 + 0x2e);
    *(short *)(param_1 + 0x30) = *(short *)(param_1 + 0x30) / 2 + *(short *)(param_1 + 0x30);
    *(short *)(param_1 + 0x32) = *(short *)(param_1 + 0x32) / 2 + *(short *)(param_1 + 0x32);
  }
  return;
}

