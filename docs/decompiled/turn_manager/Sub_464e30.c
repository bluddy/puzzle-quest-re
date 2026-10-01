
void __fastcall FUN_00464e30(int param_1)

{
  int *piVar1;
  char cVar2;
  int iVar3;
  
  iVar3 = *(int *)(param_1 + 0x2c);
  while( true ) {
    if (iVar3 == 0) {
      *(undefined4 *)(param_1 + 0x2c) = 1;
      FUN_0040ff10();
      FUN_0040fec0();
      return;
    }
    cVar2 = FUN_00464870();
    if ((cVar2 != '\0') && (cVar2 = FUN_004648f0(), cVar2 != '\0')) break;
    FUN_0040ff10();
    if (*(char *)(param_1 + 0x32) != '\0') {
      *(undefined1 *)(param_1 + 0x32) = 0;
      FUN_00464d70();
      return;
    }
    iVar3 = (*(int *)(param_1 + 0x28) + 1) % *(int *)(param_1 + 0x24);
    *(int *)(param_1 + 0x28) = iVar3;
    if (iVar3 == 0) {
      *(int *)(param_1 + 0x2c) = *(int *)(param_1 + 0x2c) + 1;
    }
    FUN_0040fec0();
    iVar3 = *(int *)(param_1 + 0x14 + *(int *)(param_1 + 4 + *(int *)(param_1 + 0x28) * 4) * 4);
    while (0 < iVar3) {
      iVar3 = *(int *)(param_1 + 4 + *(int *)(param_1 + 0x28) * 4);
      *(int *)(param_1 + 0x14 + iVar3 * 4) = *(int *)(param_1 + 0x14 + iVar3 * 4) + -1;
      iVar3 = (*(int *)(param_1 + 0x28) + 1) % *(int *)(param_1 + 0x24);
      *(int *)(param_1 + 0x28) = iVar3;
      if (iVar3 == 0) {
        *(int *)(param_1 + 0x2c) = *(int *)(param_1 + 0x2c) + 1;
      }
      FUN_0040fec0();
      iVar3 = *(int *)(param_1 + 0x14 + *(int *)(param_1 + 4 + *(int *)(param_1 + 0x28) * 4) * 4);
    }
    Engine_ADD_GOLD_447c60();
    FUN_00447120();
    cVar2 = FUN_00464870();
    if ((cVar2 != '\0') && (cVar2 = FUN_004648f0(), cVar2 != '\0')) break;
    piVar1 = (int *)(param_1 + 0x14 + *(int *)(param_1 + 4 + *(int *)(param_1 + 0x28) * 4) * 4);
    iVar3 = *piVar1;
    if (iVar3 < 1) {
      return;
    }
    *piVar1 = iVar3 + -1;
    iVar3 = *(int *)(param_1 + 0x2c);
  }
  *(undefined1 *)(param_1 + 0x31) = 1;
  return;
}

