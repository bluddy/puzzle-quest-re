
/* WARNING: Removing unreachable block (ram,0x004c7777) */

void __thiscall
FUN_004c7720(int param_1,short param_2,undefined4 param_3,undefined4 param_4,undefined1 *param_5,
            int param_6)

{
  undefined1 *puVar1;
  undefined1 *puVar2;
  undefined1 *puVar3;
  int iVar4;
  undefined1 uVar5;
  undefined1 *puVar6;
  int iVar7;
  int iVar8;
  uint uVar9;
  int iVar10;
  short sVar11;
  int iVar12;
  undefined4 local_14;
  undefined2 uStack_4;
  
  puVar6 = param_5;
  puVar1 = param_5 + 3;
  puVar2 = param_5 + 2;
  puVar3 = param_5 + 1;
  uVar5 = *param_5;
  iVar12 = 0;
  param_5 = (undefined1 *)0x0;
  local_14 = CONCAT31(CONCAT21(CONCAT11(*puVar1,uVar5),*puVar3),*puVar2);
  iVar7 = FUN_00457bf0();
  if (0 < iVar7) {
    do {
      iVar8 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
      uVar9 = (uint)*(ushort *)(iVar8 + iVar12 * 2);
      if (uVar9 == 0xa0) {
        uVar9 = 0x20;
      }
      else if ((uVar9 != 0x20) &&
              ((((int)uVar9 < *(int *)(param_1 + 0x34) || (*(int *)(param_1 + 0x30) < (int)uVar9))
               || ((iVar8 = *(int *)(param_1 + 0x3c) + (uVar9 - *(int *)(param_1 + 0x34)) * 0x20,
                   *(short *)(iVar8 + 0x14) == 0 &&
                   ((*(short *)(iVar8 + 0x10) == 0 && (*(short *)(iVar8 + 0x12) == 0)))))))) {
        uVar9 = (uint)*(ushort *)(param_1 + 0x44);
      }
      iVar10 = (uVar9 - *(int *)(param_1 + 0x34)) * 0x20;
      sVar11 = (short)param_5 + param_2;
      iVar8 = iVar10 + *(int *)(param_1 + 0x3c);
      if (0 < iVar12) {
        sVar11 = sVar11 - *(short *)(iVar10 + 0x1c + *(int *)(param_1 + 0x3c));
      }
      if (param_6 != 0) {
        local_14 = CONCAT31(CONCAT21(CONCAT11((char)(((uint)*(byte *)(iVar12 + param_6) *
                                                     (uint)(byte)puVar6[3]) / 0xff),*puVar6),
                                     puVar6[1]),puVar6[2]);
      }
      iVar4 = iVar10 + *(int *)(param_1 + 0x3c);
      FUN_004b56d0((int)*(short *)(iVar4 + 0x10),*(undefined2 *)(iVar4 + 0x12),
                   *(undefined2 *)(iVar4 + 0x14),*(undefined2 *)(iVar4 + 0x16),sVar11,param_3,
                   *(undefined4 *)(iVar8 + 0x14),CONCAT22(uStack_4,*(undefined2 *)(iVar8 + 0x16)),
                   local_14,0,0);
      if (iVar12 == 0) {
        param_5 = (undefined1 *)
                  ((int)param_5 +
                  *(int *)(iVar10 + 0x1c + *(int *)(param_1 + 0x3c)) +
                  *(int *)(iVar10 + *(int *)(param_1 + 0x3c) + 0x18));
      }
      else if (iVar12 == iVar7 + -1) {
        param_5 = (undefined1 *)
                  ((int)param_5 +
                  ((int)*(short *)(iVar10 + 0x14 + *(int *)(param_1 + 0x3c)) -
                  *(int *)(iVar10 + *(int *)(param_1 + 0x3c) + 0x1c)));
      }
      else {
        param_5 = (undefined1 *)((int)param_5 + *(int *)(iVar10 + 0x18 + *(int *)(param_1 + 0x3c)));
      }
      iVar12 = iVar12 + 1;
    } while (iVar12 < iVar7);
  }
  return;
}

