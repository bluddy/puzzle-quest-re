
bool __fastcall FUN_00464b70(int param_1)

{
  int iVar1;
  undefined4 uVar2;
  
  uVar2 = *(undefined4 *)(param_1 + 4 + *(int *)(param_1 + 0x28) * 4);
  Engine_ADD_GOLD_447c60(uVar2);
  iVar1 = Engine_ADD_GOLD_446200(uVar2);
  if (*(char *)(iVar1 + 0x10) != '\0') {
    return true;
  }
  return DAT_005af27d != '\0';
}

