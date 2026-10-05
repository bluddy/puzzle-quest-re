
/* WARNING: Removing unreachable block (ram,0x004c7681) */

int __fastcall FUN_004c7650(int param_1)

{
  int iVar1;
  int iVar2;
  int iVar3;
  uint uVar4;
  int iVar5;
  int iVar6;
  
  iVar6 = 0;
  iVar2 = FUN_00457bf0();
  iVar5 = 0;
  if (0 < iVar2) {
    do {
      iVar3 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
      uVar4 = (uint)*(ushort *)(iVar3 + iVar5 * 2);
      if (uVar4 == 0xa0) {
        uVar4 = 0x20;
      }
      else if ((uVar4 != 0x20) &&
              ((((int)uVar4 < *(int *)(param_1 + 0x34) || (*(int *)(param_1 + 0x30) < (int)uVar4))
               || ((iVar3 = *(int *)(param_1 + 0x3c) + (uVar4 - *(int *)(param_1 + 0x34)) * 0x20,
                   *(short *)(iVar3 + 0x14) == 0 &&
                   ((*(short *)(iVar3 + 0x10) == 0 && (*(short *)(iVar3 + 0x12) == 0)))))))) {
        uVar4 = (uint)*(ushort *)(param_1 + 0x44);
      }
      iVar3 = (uVar4 - *(int *)(param_1 + 0x34)) * 0x20;
      if (iVar5 == 0) {
        iVar3 = *(int *)(iVar3 + 0x1c + *(int *)(param_1 + 0x3c)) +
                *(int *)(iVar3 + *(int *)(param_1 + 0x3c) + 0x18);
      }
      else {
        iVar1 = *(int *)(param_1 + 0x3c);
        if (iVar5 == iVar2 + -1) {
          iVar3 = (int)*(short *)(iVar3 + 0x14 + iVar1) - *(int *)(iVar3 + iVar1 + 0x1c);
        }
        else {
          iVar3 = *(int *)(iVar3 + 0x18 + iVar1);
        }
      }
      iVar6 = iVar6 + iVar3;
      iVar5 = iVar5 + 1;
    } while (iVar5 < iVar2);
  }
  return iVar6;
}

