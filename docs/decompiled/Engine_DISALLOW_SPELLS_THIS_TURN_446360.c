
void __fastcall Engine_DISALLOW_SPELLS_THIS_TURN_446360(int param_1)

{
  int iVar1;
  
  iVar1 = FUN_004646e0();
  *(undefined1 *)
   (*(int *)(iVar1 + 4 + *(int *)(iVar1 + 0x28) * 4) * 0xa8 + *(int *)(param_1 + 8) + 0x14) = 0;
  return;
}

