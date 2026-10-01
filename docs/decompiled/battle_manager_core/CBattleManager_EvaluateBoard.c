
int __fastcall CBattleManager_EvaluateBoard(int param_1)

{
  bool bVar1;
  char cVar2;
  int iVar3;
  int iVar4;
  undefined4 *puVar5;
  int iVar6;
  int iVar7;
  int *piVar8;
  int local_154;
  int local_150;
  undefined1 local_14c;
  int local_148;
  undefined1 local_144 [4];
  void *local_140;
  int local_13c;
  int local_138;
  undefined1 local_134 [296];
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_0051217b;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  FUN_0043fc10();
  local_4 = 0;
  local_140 = (void *)0x0;
  local_13c = 0;
  local_138 = 0;
  Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
  iVar6 = 1;
  do {
    iVar7 = 0;
    do {
      if (iVar7 < 7) {
        bVar1 = false;
        CBoard_SwapGems_47b280(iVar7,iVar6,iVar7 + 1,iVar6);
        local_148 = 0;
        local_14c = 1;
        piVar8 = &DAT_005212dc;
        local_154 = iVar7;
        local_150 = iVar6;
        do {
          iVar3 = piVar8[-1] + iVar7;
          iVar4 = *piVar8 + iVar6;
          if ((((-1 < iVar3) && (iVar3 < 6)) && (0 < iVar4)) && (iVar4 < 9)) {
            cVar2 = CBoard_CheckMatch_47c8c0(iVar3,iVar4,1,local_134);
            if (cVar2 != '\0') {
              iVar3 = BattleAI_ScoreMatchResult_43f970(local_134);
              local_148 = local_148 + iVar3;
              bVar1 = true;
            }
          }
          piVar8 = piVar8 + 2;
        } while ((int)piVar8 < 0x5212ec);
        piVar8 = &DAT_005212ec;
        do {
          iVar3 = piVar8[-1] + iVar7;
          iVar4 = *piVar8 + iVar6;
          if (((-1 < iVar3) && (iVar3 < 8)) && ((0 < iVar4 && (iVar4 < 7)))) {
            cVar2 = CBoard_CheckMatch_47c8c0(iVar3,iVar4,0,local_134);
            if (cVar2 != '\0') {
              iVar3 = BattleAI_ScoreMatchResult_43f970(local_134);
              local_148 = local_148 + iVar3;
              bVar1 = true;
            }
          }
          iVar3 = local_13c;
          piVar8 = piVar8 + 2;
        } while ((int)piVar8 < 0x52131c);
        if (bVar1) {
          if ((local_140 == (void *)0x0) ||
             ((uint)(local_138 - (int)local_140 >> 4) <= (uint)(local_13c - (int)local_140 >> 4))) {
            BattleAI_PushCandidate_440380(local_13c,1,&local_154);
          }
          else {
            BattleAI_CandidatePush_480470(local_13c,1,&local_154,local_144,param_1);
            local_13c = iVar3 + 0x10;
          }
        }
        CBoard_SwapGems_47b280(iVar7,iVar6,iVar7 + 1,iVar6);
      }
      if (iVar6 < 8) {
        bVar1 = false;
        CBoard_SwapGems_47b280(iVar7,iVar6,iVar7,iVar6 + 1);
        local_148 = 0;
        local_14c = 0;
        piVar8 = &DAT_0052131c;
        local_154 = iVar7;
        local_150 = iVar6;
        do {
          iVar3 = piVar8[-1] + iVar7;
          iVar4 = *piVar8 + iVar6;
          if ((((-1 < iVar3) && (iVar3 < 6)) && (0 < iVar4)) && (iVar4 < 9)) {
            cVar2 = CBoard_CheckMatch_47c8c0(iVar3,iVar4,1,local_134);
            if (cVar2 != '\0') {
              iVar3 = BattleAI_ScoreMatchResult_43f970(local_134);
              local_148 = local_148 + iVar3;
              bVar1 = true;
            }
          }
          piVar8 = piVar8 + 2;
        } while ((int)piVar8 < 0x52134c);
        piVar8 = &DAT_0052134c;
        do {
          iVar3 = piVar8[-1] + iVar7;
          iVar4 = *piVar8 + iVar6;
          if (((-1 < iVar3) && (iVar3 < 8)) && ((0 < iVar4 && (iVar4 < 7)))) {
            cVar2 = CBoard_CheckMatch_47c8c0(iVar3,iVar4,0,local_134);
            if (cVar2 != '\0') {
              iVar3 = BattleAI_ScoreMatchResult_43f970(local_134);
              local_148 = local_148 + iVar3;
              bVar1 = true;
            }
          }
          iVar3 = local_13c;
          piVar8 = piVar8 + 2;
        } while ((int)piVar8 < 0x52135c);
        if (bVar1) {
          if ((local_140 == (void *)0x0) ||
             ((uint)(local_138 - (int)local_140 >> 4) <= (uint)(local_13c - (int)local_140 >> 4))) {
            BattleAI_PushCandidate_440380(local_13c,1,&local_154);
          }
          else {
            BattleAI_CandidatePush_480470(local_13c,1,&local_154,local_144,param_1);
            local_13c = iVar3 + 0x10;
          }
        }
        CBoard_SwapGems_47b280(iVar7,iVar6,iVar7,iVar6 + 1);
      }
      iVar7 = iVar7 + 1;
    } while (iVar7 < 8);
    iVar6 = iVar6 + 1;
  } while (iVar6 < 9);
  iVar6 = -1;
  iVar7 = -10000;
  iVar3 = 0;
  piVar8 = (int *)((int)local_140 + 0xc);
  while( true ) {
    if (local_140 == (void *)0x0) {
      iVar4 = 0;
    }
    else {
      iVar4 = local_13c - (int)local_140 >> 4;
    }
    if (iVar4 <= iVar3) break;
    if (iVar7 < *piVar8) {
      iVar6 = iVar3;
      iVar7 = *piVar8;
    }
    iVar3 = iVar3 + 1;
    piVar8 = piVar8 + 4;
  }
  *(int *)(param_1 + 0x40) = iVar7;
  *(bool *)(param_1 + 0x2c) = -1 < iVar6;
  if (-1 < iVar6) {
    puVar5 = (undefined4 *)(iVar6 * 0x10 + (int)local_140);
    *(undefined4 *)(param_1 + 0x30) = *puVar5;
    *(undefined4 *)(param_1 + 0x34) = puVar5[1];
    *(undefined4 *)(param_1 + 0x38) = puVar5[2];
    *(undefined4 *)(param_1 + 0x3c) = puVar5[3];
  }
  if (local_140 != (void *)0x0) {
                    /* WARNING: Subroutine does not return */
    operator_delete(local_140);
  }
  ExceptionList = local_c;
  return iVar7;
}

