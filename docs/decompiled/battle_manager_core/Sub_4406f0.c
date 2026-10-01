
/* WARNING: Removing unreachable block (ram,0x00440ace) */
/* WARNING: Removing unreachable block (ram,0x00440ae7) */
/* WARNING: Removing unreachable block (ram,0x00440b0d) */
/* WARNING: Removing unreachable block (ram,0x00440b20) */
/* WARNING: Removing unreachable block (ram,0x00440b24) */
/* WARNING: Removing unreachable block (ram,0x00440b2a) */
/* WARNING: Removing unreachable block (ram,0x00440b2e) */
/* WARNING: Removing unreachable block (ram,0x00440b37) */
/* WARNING: Removing unreachable block (ram,0x00440b52) */
/* WARNING: Removing unreachable block (ram,0x00440b54) */
/* WARNING: Removing unreachable block (ram,0x00440b8a) */
/* WARNING: Removing unreachable block (ram,0x00440b90) */
/* WARNING: Removing unreachable block (ram,0x00440b98) */
/* WARNING: Removing unreachable block (ram,0x00440bcc) */
/* WARNING: Removing unreachable block (ram,0x00440ba5) */
/* WARNING: Removing unreachable block (ram,0x00440bad) */
/* WARNING: Removing unreachable block (ram,0x00440be4) */
/* WARNING: Removing unreachable block (ram,0x00440bba) */
/* WARNING: Removing unreachable block (ram,0x00440bca) */
/* WARNING: Removing unreachable block (ram,0x00440bfa) */

undefined4 __thiscall FUN_004406f0(int param_1,undefined4 *param_2)

{
  undefined4 uVar1;
  bool bVar2;
  char cVar3;
  int iVar4;
  int iVar5;
  int iVar6;
  undefined4 *puVar7;
  int iVar8;
  undefined4 *puVar9;
  int *local_184;
  int local_180;
  int local_160;
  int local_15c;
  undefined1 local_158;
  int local_154;
  undefined4 local_150 [74];
  int local_28;
  int local_24;
  int local_20;
  int local_1c;
  void *local_14;
  undefined1 *puStack_10;
  undefined4 local_c;
  
  local_c = 0xffffffff;
  puStack_10 = &LAB_0051215b;
  local_14 = ExceptionList;
  ExceptionList = &local_14;
  FUN_0043fc10();
  iVar6 = 0;
  local_c = 0;
  Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
  uVar1 = *(undefined4 *)(param_1 + 0x48);
  *(undefined4 *)(param_1 + 0x48) = 2;
  iVar8 = 1;
  local_180 = 1;
  while( true ) {
    do {
      if (iVar6 < 7) {
        bVar2 = false;
        CBoard_SwapGems_47b280(iVar6,iVar8,iVar6 + 1,iVar8);
        local_158 = 0;
        local_154 = 0;
        local_184 = &DAT_005212dc;
        local_160 = iVar6;
        local_15c = iVar8;
        do {
          iVar4 = local_184[-1] + iVar6;
          iVar5 = *local_184 + iVar8;
          if ((((-1 < iVar4) && (iVar4 < 6)) && (0 < iVar5)) &&
             ((iVar5 < 9 && (cVar3 = CBoard_CheckMatch_47c8c0(iVar4,iVar5,1,param_2), cVar3 != '\0')
              ))) {
            iVar4 = BattleAI_ScoreMatchResult_43f970(param_2);
            local_154 = local_154 + iVar4;
            if (!bVar2) {
              puVar7 = param_2;
              puVar9 = local_150;
              for (iVar8 = 0x4a; iVar8 != 0; iVar8 = iVar8 + -1) {
                *puVar9 = *puVar7;
                puVar7 = puVar7 + 1;
                puVar9 = puVar9 + 1;
              }
              local_20 = iVar6 + 1;
              local_24 = local_180;
              local_1c = local_180;
              bVar2 = true;
              iVar8 = local_180;
              local_28 = iVar6;
            }
          }
          local_184 = local_184 + 2;
        } while ((int)local_184 < 0x5212ec);
        local_184 = &DAT_005212ec;
        do {
          iVar4 = local_184[-1] + iVar6;
          iVar5 = *local_184 + iVar8;
          if (((-1 < iVar4) && (iVar4 < 8)) &&
             ((0 < iVar5 &&
              ((iVar5 < 7 &&
               (cVar3 = CBoard_CheckMatch_47c8c0(iVar4,iVar5,0,param_2), cVar3 != '\0')))))) {
            iVar4 = BattleAI_ScoreMatchResult_43f970(param_2);
            local_154 = local_154 + iVar4;
            if (!bVar2) {
              puVar7 = param_2;
              puVar9 = local_150;
              for (iVar8 = 0x4a; iVar8 != 0; iVar8 = iVar8 + -1) {
                *puVar9 = *puVar7;
                puVar7 = puVar7 + 1;
                puVar9 = puVar9 + 1;
              }
              local_20 = iVar6 + 1;
              local_24 = local_180;
              local_1c = local_180;
              bVar2 = true;
              iVar8 = local_180;
              local_28 = iVar6;
            }
          }
          local_184 = local_184 + 2;
        } while ((int)local_184 < 0x52131c);
        if (bVar2) {
          FUN_00440660(&local_160);
        }
        CBoard_SwapGems_47b280(iVar6,iVar8,iVar6 + 1,iVar8);
      }
      if (iVar8 < 8) {
        bVar2 = false;
        CBoard_SwapGems_47b280(iVar6,iVar8,iVar6,iVar8 + 1);
        local_158 = 0;
        local_154 = 0;
        local_184 = &DAT_0052131c;
        local_160 = iVar6;
        local_15c = iVar8;
        do {
          iVar4 = local_184[-1] + iVar6;
          iVar5 = *local_184 + iVar8;
          if ((((-1 < iVar4) && (iVar4 < 6)) && (0 < iVar5)) &&
             ((iVar5 < 9 && (cVar3 = CBoard_CheckMatch_47c8c0(iVar4,iVar5,1,param_2), cVar3 != '\0')
              ))) {
            iVar4 = BattleAI_ScoreMatchResult_43f970(param_2);
            local_154 = local_154 + iVar4;
            if (!bVar2) {
              puVar7 = param_2;
              puVar9 = local_150;
              for (iVar8 = 0x4a; iVar8 != 0; iVar8 = iVar8 + -1) {
                *puVar9 = *puVar7;
                puVar7 = puVar7 + 1;
                puVar9 = puVar9 + 1;
              }
              local_24 = local_180;
              local_1c = local_180 + 1;
              bVar2 = true;
              iVar8 = local_180;
              local_28 = iVar6;
              local_20 = iVar6;
            }
          }
          local_184 = local_184 + 2;
        } while ((int)local_184 < 0x52134c);
        local_184 = &DAT_0052134c;
        do {
          iVar4 = local_184[-1] + iVar6;
          iVar5 = *local_184 + iVar8;
          if (((-1 < iVar4) && (iVar4 < 8)) &&
             ((0 < iVar5 &&
              ((iVar5 < 7 &&
               (cVar3 = CBoard_CheckMatch_47c8c0(iVar4,iVar5,0,param_2), cVar3 != '\0')))))) {
            iVar4 = BattleAI_ScoreMatchResult_43f970(param_2);
            local_154 = local_154 + iVar4;
            if (!bVar2) {
              puVar7 = param_2;
              puVar9 = local_150;
              for (iVar8 = 0x4a; iVar8 != 0; iVar8 = iVar8 + -1) {
                *puVar9 = *puVar7;
                puVar7 = puVar7 + 1;
                puVar9 = puVar9 + 1;
              }
              local_24 = local_180;
              local_1c = local_180 + 1;
              bVar2 = true;
              iVar8 = local_180;
              local_28 = iVar6;
              local_20 = iVar6;
            }
          }
          local_184 = local_184 + 2;
        } while ((int)local_184 < 0x52135c);
        if (bVar2) {
          FUN_00440660(&local_160);
        }
        CBoard_SwapGems_47b280(iVar6,iVar8,iVar6,iVar8 + 1);
      }
      iVar6 = iVar6 + 1;
    } while (iVar6 < 8);
    iVar8 = iVar8 + 1;
    if (8 < iVar8) break;
    iVar6 = 0;
    local_180 = iVar8;
  }
  *(undefined4 *)(param_1 + 0x48) = uVar1;
  ExceptionList = local_14;
  return 0;
}

