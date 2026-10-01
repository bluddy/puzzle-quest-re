
undefined4 __fastcall FUN_00464f30(int param_1)

{
  undefined4 uVar1;
  char local_97;
  
  uVar1 = *(undefined4 *)(param_1 + 4 + *(int *)(param_1 + 0x28) * 4);
  Engine_ADD_GOLD_447c60(uVar1);
  uVar1 = Engine_ADD_GOLD_446200(uVar1);
  Engine_ADD_GOLD_404570(uVar1);
  if (local_97 != '\0') {
    Engine_ADD_GOLD_4046a0();
    return 1;
  }
  Engine_ADD_GOLD_4046a0();
  return 0;
}

