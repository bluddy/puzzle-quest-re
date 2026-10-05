
/* WARNING: Removing unreachable block (ram,0x004c7608) */

undefined4 __thiscall FUN_004c75e0(int param_1,wchar_t *param_2)

{
  size_t sVar1;
  uint uVar2;
  int iVar3;
  int iVar4;
  
  sVar1 = wcslen(param_2);
  iVar4 = 0;
  if (0 < (int)sVar1) {
    do {
      uVar2 = (uint)(ushort)param_2[iVar4];
      if ((((int)uVar2 < *(int *)(param_1 + 0x34)) || (*(int *)(param_1 + 0x30) < (int)uVar2)) ||
         ((iVar3 = (uVar2 - *(int *)(param_1 + 0x34)) * 0x20 + *(int *)(param_1 + 0x3c),
          *(short *)(iVar3 + 0x14) == 0 &&
          ((*(short *)(iVar3 + 0x10) == 0 && (*(short *)(iVar3 + 0x12) == 0)))))) {
        return 0;
      }
      iVar4 = iVar4 + 1;
    } while (iVar4 < (int)sVar1);
  }
  return 1;
}

