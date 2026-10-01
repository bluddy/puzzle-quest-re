// refs 0x0043f870 @ 0044bb34

void __thiscall FUN_0044a780(int param_1,char param_2)

{
  short sVar1;
  bool bVar2;
  char cVar3;
  int iVar4;
  undefined4 uVar5;
  int *piVar6;
  int iVar7;
  int iVar8;
  uint uVar9;
  int iVar10;
  int *piVar11;
  undefined4 *puVar12;
  int **ppiVar13;
  undefined4 uVar14;
  undefined1 *puVar15;
  int *piVar16;
  int *local_5d4;
  int aiStack_5d0 [4];
  short sStack_5c0;
  short sStack_5be;
  short sStack_5bc;
  short sStack_5ba;
  int local_5b8;
  int local_5b4;
  int *piStack_5b0;
  undefined4 uStack_5ac;
  undefined4 uStack_5a8;
  undefined4 uStack_5a4;
  undefined1 uStack_5a0;
  undefined1 uStack_59f;
  undefined1 uStack_59e;
  undefined1 uStack_59d;
  undefined4 uStack_598;
  void *pvStack_584;
  undefined4 uStack_580;
  undefined4 uStack_57c;
  void *pvStack_574;
  undefined4 uStack_570;
  undefined4 uStack_56c;
  void *pvStack_564;
  undefined4 uStack_560;
  undefined4 uStack_55c;
  void *pvStack_554;
  undefined4 uStack_550;
  undefined4 uStack_54c;
  undefined4 uStack_548;
  undefined4 uStack_544;
  undefined4 uStack_540;
  undefined4 uStack_53c;
  undefined4 uStack_538;
  undefined4 uStack_534;
  undefined4 uStack_530;
  uint auStack_52c [4];
  undefined4 auStack_51c [4];
  undefined4 uStack_50c;
  int *local_508;
  undefined4 local_504;
  undefined4 local_500;
  undefined4 local_4fc;
  undefined1 local_4f8;
  undefined1 local_4f7;
  undefined1 local_4f6;
  undefined1 local_4f5;
  undefined4 local_4f0;
  void *local_4dc;
  undefined4 local_4d8;
  undefined4 local_4d4;
  void *local_4cc;
  undefined4 local_4c8;
  undefined4 local_4c4;
  void *local_4bc;
  undefined4 local_4b8;
  undefined4 local_4b4;
  void *local_4ac;
  undefined4 local_4a8;
  undefined4 local_4a4;
  uint local_4a0 [11];
  undefined4 auStack_474 [4];
  undefined4 local_464;
  int *local_460;
  undefined4 local_45c;
  undefined4 local_458;
  undefined4 local_454;
  undefined1 local_450;
  bool local_44f;
  undefined1 local_44e;
  undefined1 local_44d;
  uint local_448;
  uint local_3f8 [11];
  undefined4 auStack_3cc [4];
  undefined4 local_3bc;
  int *local_3b8;
  undefined4 local_3b4;
  undefined4 local_3b0;
  undefined4 local_3ac;
  undefined1 local_3a8;
  bool local_3a7;
  undefined1 local_3a6;
  undefined1 local_3a5;
  uint local_3a0;
  int local_350 [11];
  undefined4 auStack_324 [4];
  undefined4 local_314;
  int iStack_2e8;
  undefined1 auStack_2d0 [72];
  int aiStack_288 [20];
  int iStack_238;
  int aiStack_234 [8];
  undefined1 uStack_214;
  int iStack_1dc;
  int iStack_184;
  int *piStack_180;
  int iStack_17c;
  int iStack_60;
  undefined1 auStack_5c [24];
  short asStack_44 [7];
  short sStack_36;
  short sStack_34;
  int iStack_2c;
  int iStack_28;
  void *pvStack_1c;
  int iStack_18;
  undefined4 local_10;
  void *pvStack_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00512c04;
  pvStack_c = ExceptionList;
  local_10 = DAT_0057faa0;
  ExceptionList = &pvStack_c;
  local_5b8 = param_1;
  if (param_2 == '\0') {
    ExceptionList = &pvStack_c;
    FUN_00447e00();
  }
  DAT_005828fc = DAT_005828fc + 1;
  iVar4 = FUN_004bd310();
  *(int *)(param_1 + 0x24) = iVar4 % 1000 + DAT_005828fc;
  FUN_00408000();
  Engine_ADD_ANIMEFFECT_TO_GRID_483380();
  FUN_00483100();
  iVar4 = *(int *)(param_1 + 4);
  *(undefined4 *)(param_1 + 0x20) = 1;
  bVar2 = true;
  aiStack_5d0[3] = 0;
  local_5b4 = 0;
  if (((((iVar4 == 0) || (iVar4 == 3)) || (iVar4 == 1)) || ((iVar4 == 2 || (iVar4 == 6)))) ||
     ((iVar4 == 8 || (iVar4 == 7)))) {
    uVar14 = 0;
    uVar5 = Engine_TUTORIAL_GET_HERO_475a90(0,0);
    Engine_QUEST_ABANDON_44e920(uVar5);
    piVar6 = (int *)Engine_QUEST_ABANDON_44d8e0(uVar5,uVar14);
    local_4dc = (void *)0x0;
    local_4d8 = 0;
    local_4d4 = 0;
    local_4cc = (void *)0x0;
    local_4c8 = 0;
    local_4c4 = 0;
    local_4bc = (void *)0x0;
    local_4b8 = 0;
    local_4b4 = 0;
    local_4ac = (void *)0x0;
    local_4a8 = 0;
    local_4a4 = 0;
    local_504 = 0;
    local_500 = 0;
    local_4fc = 0;
    local_4f8 = 1;
    local_4f7 = 1;
    local_4f6 = 1;
    local_4f5 = 0;
    local_4f0 = 0;
    piVar6[0x11] = 0;
    local_5d4 = piVar6 + 0x2b;
    local_4 = 3;
    local_464 = 0;
    local_4a0[0] = 0;
    local_4a0[1] = 0;
    local_4a0[2] = 0;
    local_4a0[3] = 0;
    local_4a0[4] = 0;
    local_4a0[5] = 0;
    local_4a0[6] = 0;
    iVar4 = 0;
    local_508 = piVar6;
    do {
      uVar9 = (**(code **)(*piVar6 + 0x20))(0x12,*local_5d4,piVar6[0x11],iVar4);
      uVar9 = uVar9 & ((int)uVar9 < 1) - 1;
      if (100 < (int)uVar9) {
        uVar9 = 100;
      }
      local_4a0[iVar4 + 7] = uVar9;
      auStack_474[iVar4] = 0;
      iVar4 = iVar4 + 1;
      local_5d4 = local_5d4 + 1;
    } while (iVar4 < 4);
    iVar4 = piVar6[0x6d];
    if ((-1 < iVar4) && (*(int *)(piVar6[0x52] + iVar4 * 6) != 0)) {
      aiStack_5d0[0] = *(int *)(piVar6[0x52] + iVar4 * 6);
      iVar4 = FUN_004561a0();
      iVar7 = FUN_004560d0(aiStack_5d0[0]);
      iVar4 = iVar7 * 0x270 + *(int *)(iVar4 + 8);
      if (piVar6[0x6d] < 0) {
        iVar7 = 0;
      }
      else {
        iVar7 = (int)*(short *)(piVar6[0x52] + piVar6[0x6d] * 6 + 4);
      }
      local_4a0[*(int *)(iVar4 + 300)] =
           local_4a0[*(int *)(iVar4 + 300)] +
           (iVar7 / *(int *)(iVar4 + 0x134)) * *(int *)(iVar4 + 0x130) + *(int *)(iVar4 + 0x128);
    }
    iVar4 = *(int *)(param_1 + 4);
    if (iVar4 == 3) {
      iVar4 = *(int *)(param_1 + 8);
      iVar7 = FUN_004561a0();
      aiStack_5d0[0] = iVar4 * 0x270 + *(int *)(iVar7 + 8);
      iVar7 = FUN_004561a0();
      FUN_004102a0();
      FUN_0044a6f0(aiStack_5d0[0]);
      if (*(int *)(iVar7 + 8) == 0) {
        iVar4 = 0;
      }
      else {
        iVar4 = (*(int *)(iVar7 + 0xc) - *(int *)(iVar7 + 8)) / 0x270;
      }
      iVar4 = iVar4 + -1;
      *(undefined1 *)(iVar4 * 0x270 + *(int *)(iVar7 + 8) + 0x268) = 1;
      FUN_00410250();
      aiStack_5d0[3] = DAT_00582450;
      *(int *)(param_1 + 0x1c) = (int)DAT_005806b4;
    }
    else if (iVar4 == 0) {
      iVar4 = local_508[0x1a];
      FUN_004561a0(iVar4,piVar6);
      iVar4 = FUN_00456220(iVar4,piVar6);
      iVar7 = FUN_004561a0();
      aiStack_5d0[0] = iVar4 * 0x270 + *(int *)(iVar7 + 8);
      iVar7 = FUN_004561a0();
      FUN_004102a0();
      FUN_0044a6f0(aiStack_5d0[0]);
      if (*(int *)(iVar7 + 8) == 0) {
        iVar4 = 0;
      }
      else {
        iVar4 = (*(int *)(iVar7 + 0xc) - *(int *)(iVar7 + 8)) / 0x270;
      }
      iVar4 = iVar4 + -1;
      *(undefined1 *)(iVar4 * 0x270 + *(int *)(iVar7 + 8) + 0x268) = 1;
      FUN_00410250();
      aiStack_5d0[3] = DAT_00582450;
LAB_0044b946:
      *(undefined4 *)(param_1 + 0x1c) = 0;
    }
    else if (iVar4 == 2) {
      iVar4 = *(int *)(param_1 + 0x18);
      iVar7 = FUN_004561a0();
      iVar7 = *(int *)(iVar7 + 8);
      iVar8 = FUN_004561a0();
      FUN_004102a0();
      FUN_0044a6f0(iVar4 * 0x270 + iVar7);
      if (*(int *)(iVar8 + 8) == 0) {
        iVar4 = 0;
      }
      else {
        iVar4 = (*(int *)(iVar8 + 0xc) - *(int *)(iVar8 + 8)) / 0x270;
      }
      iVar4 = iVar4 + -1;
      *(undefined1 *)(iVar4 * 0x270 + *(int *)(iVar8 + 8) + 0x268) = 1;
      FUN_00410250();
    }
    else {
      if (iVar4 == 7) {
        uVar5 = *(undefined4 *)(param_1 + 0x30);
        iVar4 = FUN_004561a0();
        iVar7 = FUN_004560d0(uVar5);
        FUN_00471b00(iVar7 * 0x270 + *(int *)(iVar4 + 8));
        iVar4 = 0x12 - *(int *)(param_1 + 0x34);
        local_4 = CONCAT31(local_4._1_3_,4);
        if (iVar4 < 4) {
          iVar4 = 3;
        }
        bVar2 = false;
        *(undefined4 *)(param_1 + 0x1c) = 0;
        FUN_00471660(iStack_1dc + -1 + *(int *)(param_1 + 0x34),1,1);
        iVar7 = Engine_EXTRA_TURN_4646e0();
        *(int *)(iVar7 + 0x34) = -iVar4;
        iVar7 = FUN_004561a0();
        FUN_004102a0();
        FUN_0044a6f0(auStack_2d0);
        if (*(int *)(iVar7 + 8) == 0) {
          iVar4 = 0;
        }
        else {
          iVar4 = (int)((ulonglong)
                        ((longlong)(*(int *)(iVar7 + 0xc) - *(int *)(iVar7 + 8)) * 0xd20d20d3) >>
                       0x20);
LAB_0044b1f8:
          iVar4 = (iVar4 >> 9) - (iVar4 >> 0x1f);
        }
      }
      else if (iVar4 == 6) {
        *(undefined4 *)(param_1 + 0x1c) = 0;
        iVar4 = FUN_004561a0();
        iVar7 = FUN_004560d0(0x5449434d);
        FUN_00471b00(iVar7 * 0x270 + *(int *)(iVar4 + 8));
        uVar5 = *(undefined4 *)(param_1 + 0x28);
        local_4 = CONCAT31(local_4._1_3_,5);
        FUN_00442e40(uVar5);
        iVar4 = FUN_00419340(uVar5);
        Engine_TUTORIAL_GAME_RUN_4be780(iVar4 + 4);
        local_5d4 = (int *)(iVar4 + 0x470);
        uStack_214 = 1;
        aiStack_5d0[0] = 4;
        do {
          iVar7 = *local_5d4;
          if (iVar7 != 0) {
            Engine_GET_CURRENT_RUNE_CODE_44f8e0(iVar7);
            iVar7 = Engine_SET_ITEM_41f6e0(iVar7);
            if (-1 < iVar7) {
              iVar8 = Engine_GET_CURRENT_RUNE_CODE_44f8e0();
              FUN_00418930(iVar7 * 0x40 + *(int *)(iVar8 + 8));
              iVar8 = iStack_2e8;
              piVar6 = aiStack_288;
              local_4._0_1_ = 6;
              Engine_ADD_MAX_LIFE_445030(piVar6);
              Engine_ADD_MAX_LIFE_444d40(piVar6);
              piVar6 = aiStack_288;
              aiStack_234[iVar8] = iVar7;
              Engine_ADD_MAX_LIFE_445030(piVar6);
              Engine_ADD_MAX_LIFE_444d80(piVar6);
              uStack_214 = 1;
              local_4 = CONCAT31(local_4._1_3_,5);
              FUN_0046ff80();
            }
          }
          local_5d4 = local_5d4 + 1;
          aiStack_5d0[0] = aiStack_5d0[0] + -1;
        } while (aiStack_5d0[0] != 0);
        piVar6 = (int *)(iVar4 + 0x460);
        aiStack_5d0[0] = 4;
        do {
          iVar4 = *piVar6;
          if (iVar4 != 0) {
            Engine_HANDLE_SPELL_COST_4622c0(iVar4);
            piVar11 = (int *)FUN_00461d30(iVar4);
            if (-1 < (int)piVar11) {
              local_5d4 = piVar11;
              if ((iStack_184 == 0) ||
                 ((uint)(iStack_17c - iStack_184 >> 2) <= (uint)((int)piStack_180 - iStack_184 >> 2)
                 )) {
                FUN_004292c0(piStack_180,1,&local_5d4);
              }
              else {
                *piStack_180 = (int)piVar11;
                piStack_180 = piStack_180 + 1;
              }
            }
          }
          piVar6 = piVar6 + 1;
          aiStack_5d0[0] = aiStack_5d0[0] + -1;
        } while (aiStack_5d0[0] != 0);
        iVar7 = FUN_004561a0();
        FUN_004102a0();
        FUN_0044a6f0(auStack_2d0);
        iVar4 = *(int *)(iVar7 + 8);
        if (iVar4 != 0) {
LAB_0044b5b8:
          iVar4 = (int)((ulonglong)((longlong)(*(int *)(iVar7 + 0xc) - iVar4) * 0xd20d20d3) >> 0x20)
          ;
          goto LAB_0044b1f8;
        }
        iVar4 = 0;
      }
      else {
        if (iVar4 != 8) {
          if (iVar4 != 1) {
            iVar4 = local_508[0x1a];
            aiStack_5d0[3] = DAT_00582450;
            FUN_004561a0(iVar4,piVar6);
            iVar4 = FUN_00456220(iVar4,piVar6);
            goto LAB_0044b946;
          }
          FUN_00471930();
          iVar8 = local_5b8;
          iVar4 = *(int *)(local_5b8 + 0xc);
          local_4._0_1_ = 10;
          iVar7 = FUN_0045adc0();
          iVar7 = *(int *)(iVar7 + 0x10);
          iVar4 = iVar4 * 0x80;
          FUN_00448b30(*(int *)(iVar8 + 0x10) * 0x50 + *(int *)(iVar4 + 0x38 + iVar7));
          local_4 = CONCAT31(local_4._1_3_,0xb);
          aiStack_5d0[0] = iStack_60;
          iVar8 = FUN_004561a0();
          iVar10 = FUN_004560d0(aiStack_5d0[0]);
          FUN_00428810(iVar10 * 0x270 + *(int *)(iVar8 + 8));
          uVar5 = *(undefined4 *)(iVar4 + iVar7 + 4);
          iVar4 = FUN_0045adc0();
          *(undefined4 *)(iVar4 + 4) = uVar5;
          uVar5 = *(undefined4 *)((int)piVar6 + 0x1c7);
          iVar4 = FUN_0045adc0();
          *(undefined4 *)(iVar4 + 8) = uVar5;
          cVar3 = FUN_004bdb40();
          if (cVar3 == '\0') {
            puVar15 = auStack_5c;
            Engine_GET_TEXT_4b4500(puVar15);
            Engine_GET_TEXT_4b4050(puVar15);
            uVar5 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
            Engine_TUTORIAL_GAME_RUN_4be780(uVar5);
            uStack_214 = 1;
          }
          iVar4 = 0;
          do {
            sVar1 = asStack_44[iVar4];
            if (sVar1 != 0) {
              piVar6 = aiStack_288;
              Engine_ADD_MAX_LIFE_445030(piVar6);
              Engine_ADD_MAX_LIFE_444d40(piVar6);
              aiStack_288[iVar4] = aiStack_288[iVar4] + (int)sVar1;
              piVar6 = aiStack_288;
              Engine_ADD_MAX_LIFE_445030(piVar6);
              Engine_ADD_MAX_LIFE_444d80(piVar6);
            }
            iVar4 = iVar4 + 1;
          } while (iVar4 < 7);
          if (sStack_34 != 0) {
            local_5b4 = (int)sStack_34;
          }
          if (sStack_36 != 0) {
            piVar6 = aiStack_288;
            Engine_ADD_MAX_LIFE_445030(piVar6);
            Engine_ADD_MAX_LIFE_444d40(piVar6);
            iStack_238 = iStack_238 + sStack_36;
            piVar6 = aiStack_288;
            Engine_ADD_MAX_LIFE_445030(piVar6);
            Engine_ADD_MAX_LIFE_444d80(piVar6);
          }
          iVar4 = 0;
          while( true ) {
            if (iStack_2c == 0) {
              iVar7 = 0;
            }
            else {
              iVar7 = iStack_28 - iStack_2c >> 2;
            }
            if (iVar7 <= iVar4) break;
            uVar5 = *(undefined4 *)(iStack_2c + iVar4 * 4);
            Engine_GET_CURRENT_RUNE_CODE_44f8e0(uVar5);
            iVar7 = Engine_SET_ITEM_41f6e0(uVar5);
            if (-1 < iVar7) {
              iVar8 = Engine_GET_CURRENT_RUNE_CODE_44f8e0();
              FUN_00418930(iVar7 * 0x40 + *(int *)(iVar8 + 8));
              iVar8 = iStack_2e8;
              piVar6 = aiStack_288;
              local_4._0_1_ = 0xc;
              Engine_ADD_MAX_LIFE_445030(piVar6);
              Engine_ADD_MAX_LIFE_444d40(piVar6);
              piVar6 = aiStack_288;
              aiStack_234[iVar8] = iVar7;
              Engine_ADD_MAX_LIFE_445030(piVar6);
              Engine_ADD_MAX_LIFE_444d80(piVar6);
              uStack_214 = 1;
              local_4 = CONCAT31(local_4._1_3_,0xb);
              FUN_0046ff80();
            }
            iVar4 = iVar4 + 1;
          }
          iVar4 = 0;
          while( true ) {
            if (pvStack_1c == (void *)0x0) {
              iVar7 = 0;
            }
            else {
              iVar7 = iStack_18 - (int)pvStack_1c >> 2;
            }
            if (iVar7 <= iVar4) break;
            uVar5 = *(undefined4 *)((int)pvStack_1c + iVar4 * 4);
            Engine_HANDLE_SPELL_COST_4622c0(uVar5);
            aiStack_5d0[0] = FUN_00461d30(uVar5);
            if ((iStack_184 == 0) ||
               ((uint)(iStack_17c - iStack_184 >> 2) <= (uint)((int)piStack_180 - iStack_184 >> 2)))
            {
              FUN_004292c0(piStack_180,1,aiStack_5d0);
              iVar4 = iVar4 + 1;
            }
            else {
              *piStack_180 = aiStack_5d0[0];
              iVar4 = iVar4 + 1;
              piStack_180 = piStack_180 + 1;
            }
          }
          iVar7 = FUN_004561a0();
          FUN_004102a0();
          FUN_0044a6f0(auStack_2d0);
          if (*(int *)(iVar7 + 8) == 0) {
            iVar4 = 0;
          }
          else {
            iVar4 = (*(int *)(iVar7 + 0xc) - *(int *)(iVar7 + 8)) / 0x270;
          }
          iVar4 = iVar4 + -1;
          *(undefined1 *)(iVar4 * 0x270 + *(int *)(iVar7 + 8) + 0x268) = 1;
          FUN_00410250();
          local_4._0_1_ = 10;
          FUN_00427f80();
          local_4 = CONCAT31(local_4._1_3_,3);
          FUN_00471ed0();
          goto LAB_0044b949;
        }
        uVar5 = *(undefined4 *)(param_1 + 0x2c);
        *(undefined4 *)(param_1 + 0x1c) = 0;
        Engine_GET_CURRENT_RUNE_BASEDATA_460a80(uVar5);
        iVar4 = FUN_0045f160(uVar5);
        uVar5 = *(undefined4 *)(iVar4 + 0x20);
        iVar7 = FUN_004561a0();
        iVar8 = FUN_004560d0(uVar5);
        FUN_00471b00(iVar8 * 0x270 + *(int *)(iVar7 + 8));
        local_4._0_1_ = 7;
        FUN_00471660(*(undefined4 *)(iVar4 + 0x24),1,1);
        Engine_ACTIVATE_COMPANION_4be530(L"[RUNEKEEPER]",0xffffffff);
        piVar6 = aiStack_5d0;
        local_4._0_1_ = 8;
        Engine_GET_TEXT_4b4500(piVar6);
        Engine_GET_TEXT_4b4050(piVar6);
        uVar5 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
        Engine_TUTORIAL_GAME_RUN_4be780(uVar5);
        uStack_214 = 1;
        local_4 = CONCAT31(local_4._1_3_,7);
        Engine_ACTIVATE_COMPANION_4bdf40();
        uVar5 = 0x544b5249;
        Engine_GET_CURRENT_RUNE_CODE_44f8e0(0x544b5249);
        aiStack_5d0[0] = Engine_SET_ITEM_41f6e0(uVar5);
        uVar5 = 0x4b4b5249;
        Engine_GET_CURRENT_RUNE_CODE_44f8e0(0x4b4b5249);
        aiStack_5d0[1] = Engine_SET_ITEM_41f6e0(uVar5);
        iVar4 = 0;
        do {
          iVar7 = aiStack_5d0[iVar4];
          if (-1 < iVar7) {
            iVar8 = Engine_GET_CURRENT_RUNE_CODE_44f8e0();
            FUN_00418930(iVar7 * 0x40 + *(int *)(iVar8 + 8));
            iVar8 = iStack_2e8;
            piVar6 = aiStack_288;
            local_4._0_1_ = 9;
            Engine_ADD_MAX_LIFE_445030(piVar6);
            Engine_ADD_MAX_LIFE_444d40(piVar6);
            piVar6 = aiStack_288;
            aiStack_234[iVar8] = iVar7;
            Engine_ADD_MAX_LIFE_445030(piVar6);
            Engine_ADD_MAX_LIFE_444d80(piVar6);
            uStack_214 = 1;
            local_4 = CONCAT31(local_4._1_3_,7);
            FUN_0046ff80();
          }
          iVar4 = iVar4 + 1;
        } while (iVar4 < 2);
        iVar7 = FUN_004561a0();
        FUN_004102a0();
        FUN_0044a6f0(auStack_2d0);
        iVar4 = *(int *)(iVar7 + 8);
        if (iVar4 != 0) goto LAB_0044b5b8;
        iVar4 = 0;
      }
      iVar4 = iVar4 + -1;
      *(undefined1 *)(iVar4 * 0x270 + *(int *)(iVar7 + 8) + 0x268) = 1;
      FUN_00410250();
      local_4 = CONCAT31(local_4._1_3_,3);
      FUN_00471ed0();
    }
LAB_0044b949:
    pvStack_584 = (void *)0x0;
    uStack_580 = 0;
    uStack_57c = 0;
    pvStack_574 = (void *)0x0;
    uStack_570 = 0;
    uStack_56c = 0;
    pvStack_564 = (void *)0x0;
    uStack_560 = 0;
    uStack_55c = 0;
    pvStack_554 = (void *)0x0;
    uStack_550 = 0;
    uStack_54c = 0;
    local_4 = CONCAT31(local_4._1_3_,0x10);
    iVar7 = FUN_004561a0();
    piStack_5b0 = (int *)(iVar4 * 0x270 + *(int *)(iVar7 + 8));
    uStack_5ac = 3;
    uStack_5a8 = 1;
    uStack_5a4 = 1;
    uStack_5a0 = 0;
    uStack_59f = 1;
    uStack_59e = 1;
    uStack_59d = 0;
    uStack_598 = 2;
    piStack_5b0[0x11] = 1;
    iVar4 = 0;
    uStack_50c = 0;
    uStack_548 = 0;
    uStack_544 = 0;
    uStack_540 = 0;
    uStack_53c = 0;
    uStack_538 = 0;
    uStack_534 = 0;
    uStack_530 = 0;
    do {
      uVar9 = (**(code **)(*piStack_5b0 + 0x20))
                        (0x12,piStack_5b0[iVar4 + 0x2b],piStack_5b0[0x11],iVar4);
      uVar9 = uVar9 & ((int)uVar9 < 1) - 1;
      if (100 < (int)uVar9) {
        uVar9 = 100;
      }
      auStack_52c[iVar4] = uVar9;
      auStack_51c[iVar4] = 0;
      iVar4 = iVar4 + 1;
    } while (iVar4 < 4);
    if ((*(int *)(local_5b8 + 0x1c) != 0) && (piStack_5b0[0x1a] < local_508[0x1a])) {
      (**(code **)(*piStack_5b0 + 8))(local_508[0x1a],0,DAT_00582454);
    }
    piVar6 = piStack_5b0;
    iVar4 = local_5b4;
    if (0 < local_5b4) {
      piVar11 = piStack_5b0 + 0x12;
      piVar16 = piVar11;
      Engine_ADD_MAX_LIFE_445030(piVar11);
      Engine_ADD_MAX_LIFE_444d40(piVar16);
      piVar6[0x1a] = piVar6[0x1a] + iVar4;
      Engine_ADD_MAX_LIFE_445030(piVar11);
      Engine_ADD_MAX_LIFE_444d80(piVar11);
      *(undefined1 *)(piVar6 + 0x2f) = 1;
    }
    DAT_005af278 = 1;
    Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
    Engine_TUTORIAL_GAME_PLAY_47aa70();
    Engine_ADD_GOLD_447c60();
    FUN_00447cd0();
    ppiVar13 = &local_508;
    Engine_ADD_GOLD_447c60(ppiVar13);
    FUN_00447cf0(ppiVar13);
    ppiVar13 = &piStack_5b0;
    Engine_ADD_GOLD_447c60(ppiVar13);
    FUN_00447cf0(ppiVar13);
    Engine_ADD_GOLD_447c60();
    FUN_00446be0();
    if (bVar2) {
      iVar4 = Engine_EXTRA_TURN_4646e0();
      *(int *)(iVar4 + 0x34) = aiStack_5d0[3];
    }
    uVar5 = DAT_00582454;
    iVar4 = CBattleManager_GetSingleton();
    *(undefined4 *)(iVar4 + 0x48) = uVar5;
    if (pvStack_554 != (void *)0x0) {
                    /* WARNING: Subroutine does not return */
      operator_delete(pvStack_554);
    }
    pvStack_554 = (void *)0x0;
    uStack_550 = 0;
    uStack_54c = 0;
    if (pvStack_564 != (void *)0x0) {
                    /* WARNING: Subroutine does not return */
      operator_delete(pvStack_564);
    }
    pvStack_564 = (void *)0x0;
    uStack_560 = 0;
    uStack_55c = 0;
    if (pvStack_574 != (void *)0x0) {
                    /* WARNING: Subroutine does not return */
      operator_delete(pvStack_574);
    }
    pvStack_574 = (void *)0x0;
    uStack_570 = 0;
    uStack_56c = 0;
    if (pvStack_584 != (void *)0x0) {
                    /* WARNING: Subroutine does not return */
      operator_delete(pvStack_584);
    }
    pvStack_584 = (void *)0x0;
    uStack_580 = 0;
    uStack_57c = 0;
    local_4 = 0xffffffff;
    if (local_4ac != (void *)0x0) {
                    /* WARNING: Subroutine does not return */
      operator_delete(local_4ac);
    }
    local_4ac = (void *)0x0;
    local_4a8 = 0;
    local_4a4 = 0;
    if (local_4bc != (void *)0x0) {
                    /* WARNING: Subroutine does not return */
      operator_delete(local_4bc);
    }
    local_4bc = (void *)0x0;
    local_4b8 = 0;
    local_4b4 = 0;
    if (local_4cc != (void *)0x0) {
                    /* WARNING: Subroutine does not return */
      operator_delete(local_4cc);
    }
    local_4cc = (void *)0x0;
    local_4c8 = 0;
    local_4c4 = 0;
    if (local_4dc != (void *)0x0) {
                    /* WARNING: Subroutine does not return */
      operator_delete(local_4dc);
    }
    goto LAB_0044bc62;
  }
  if (iVar4 != 4) goto LAB_0044bc62;
  DAT_00580f42 = 0;
  DAT_00580f41 = 0;
  DAT_00580f40 = 0;
  FUN_004d1e20();
  cVar3 = FUN_004d1940();
  uVar9 = (uint)(cVar3 == '\0');
  aiStack_5d0[3] = uVar9;
  FUN_00448be0();
  local_4 = 0x11;
  iVar4 = FUN_004d1e20();
  if ((*(int *)(iVar4 + 0x7c) == 5) || (uVar9 == 0)) {
    uVar14 = 0;
    uVar5 = Engine_TUTORIAL_GET_HERO_475a90(0,0);
    Engine_QUEST_ABANDON_44e920(uVar5);
    piVar6 = (int *)Engine_QUEST_ABANDON_44d8e0(uVar5,uVar14);
  }
  else {
    Engine_QUEST_ABANDON_44e920();
    piVar6 = (int *)FUN_0044cd20();
  }
  local_3b8 = piVar6;
  if (uVar9 == 0) {
    local_3a7 = true;
  }
  else {
    iVar4 = FUN_004d1e20();
    local_3a7 = *(int *)(iVar4 + 0x7c) == 5;
  }
  local_3a0 = -(uint)(uVar9 != 0) & 2;
  local_3b4 = 0;
  local_3b0 = 0;
  local_3ac = 0;
  local_3a8 = 1;
  local_3a6 = 1;
  local_3a5 = 0;
  local_3b8[0x11] = 0;
  local_314 = 0;
  local_350[0] = 0;
  local_350[1] = 0;
  local_350[2] = 0;
  local_350[3] = 0;
  local_350[4] = 0;
  local_350[5] = 0;
  local_350[6] = 0;
  iVar4 = 0;
  do {
    iVar7 = FUN_00445bc0(iVar4);
    local_350[iVar4 + 7] = iVar7;
    auStack_324[iVar4] = 0;
    iVar4 = iVar4 + 1;
  } while (iVar4 < 4);
  if ((-1 < piVar6[0x6d]) && (*(int *)(piVar6[0x52] + piVar6[0x6d] * 6) != 0)) {
    uVar5 = FUN_00427ec0();
    FUN_004561a0(uVar5);
    iVar7 = FUN_004285e0(uVar5);
    iVar4 = *(int *)(iVar7 + 300);
    iVar8 = FUN_00427ee0();
    local_350[iVar4] =
         local_350[iVar4] +
         (iVar8 / *(int *)(iVar7 + 0x134)) * *(int *)(iVar7 + 0x130) + *(int *)(iVar7 + 0x128);
    uVar9 = aiStack_5d0[3];
  }
  FUN_00448be0();
  local_4 = CONCAT31(local_4._1_3_,0x12);
  iVar4 = FUN_004d1e20();
  if (*(int *)(iVar4 + 0x7c) == 5) {
    uVar14 = 1;
    uVar5 = 1;
LAB_0044aa44:
    uVar5 = Engine_TUTORIAL_GET_HERO_475a90(uVar5,uVar14);
    Engine_QUEST_ABANDON_44e920(uVar5);
    piVar6 = (int *)Engine_QUEST_ABANDON_44d8e0(uVar5,uVar14);
  }
  else {
    if (uVar9 == 1) {
      uVar14 = 0;
      uVar5 = 0;
      goto LAB_0044aa44;
    }
    Engine_QUEST_ABANDON_44e920();
    piVar6 = (int *)FUN_0044cd20();
  }
  local_460 = piVar6;
  if (uVar9 == 1) {
    local_44f = true;
  }
  else {
    iVar4 = FUN_004d1e20();
    local_44f = *(int *)(iVar4 + 0x7c) == 5;
  }
  local_448 = -(uint)(aiStack_5d0[3] != 1) & 2;
  local_45c = 3;
  local_458 = 1;
  local_454 = 1;
  local_450 = 1;
  local_44e = 1;
  local_44d = 0;
  local_460[0x11] = 1;
  local_3bc = 0;
  local_3f8[0] = 0;
  local_3f8[1] = 0;
  local_3f8[2] = 0;
  local_3f8[3] = 0;
  local_3f8[4] = 0;
  local_3f8[5] = 0;
  local_3f8[6] = 0;
  iVar4 = 0;
  piVar11 = piVar6 + 0x2b;
  do {
    uVar9 = (**(code **)(*piVar6 + 0x20))(0x12,*piVar11,piVar6[0x11],iVar4);
    uVar9 = uVar9 & ((int)uVar9 < 1) - 1;
    if (100 < (int)uVar9) {
      uVar9 = 100;
    }
    local_3f8[iVar4 + 7] = uVar9;
    auStack_3cc[iVar4] = 0;
    iVar4 = iVar4 + 1;
    piVar11 = piVar11 + 1;
  } while (iVar4 < 4);
  iVar4 = piVar6[0x6d];
  if ((-1 < iVar4) && (*(int *)(piVar6[0x52] + iVar4 * 6) != 0)) {
    uVar5 = *(undefined4 *)(piVar6[0x52] + iVar4 * 6);
    iVar4 = FUN_004561a0();
    iVar7 = FUN_004560d0(uVar5);
    iVar4 = iVar7 * 0x270 + *(int *)(iVar4 + 8);
    if (piVar6[0x6d] < 0) {
      iVar7 = 0;
    }
    else {
      iVar7 = (int)*(short *)(piVar6[0x52] + piVar6[0x6d] * 6 + 4);
    }
    local_3f8[*(int *)(iVar4 + 300)] =
         local_3f8[*(int *)(iVar4 + 300)] +
         (iVar7 / *(int *)(iVar4 + 0x134)) * *(int *)(iVar4 + 0x130) + *(int *)(iVar4 + 0x128);
  }
  DAT_005af278 = 1;
  Engine_ADD_GOLD_447c60();
  FUN_00447cd0();
  if (DAT_00583582 != '\0') {
    iVar8 = FUN_0044a110(&local_3b8);
    iVar10 = FUN_0044a110(&local_460);
    iVar4 = local_3b8[0x1a];
    iVar7 = local_460[0x1a];
    if (iVar7 < iVar4) {
      iVar4 = iVar4 - iVar7;
      ppiVar13 = &local_460;
LAB_0044ac61:
      FUN_0044a210(ppiVar13,iVar4);
    }
    else if (iVar4 < iVar7) {
      iVar4 = iVar7 - iVar4;
      ppiVar13 = &local_3b8;
      goto LAB_0044ac61;
    }
    if (iVar10 < iVar8) {
      iVar8 = iVar8 - iVar10;
      ppiVar13 = &local_460;
    }
    else {
      if (iVar10 <= iVar8) goto LAB_0044ac8d;
      iVar8 = iVar10 - iVar8;
      ppiVar13 = &local_3b8;
    }
    FUN_00449fa0(ppiVar13,iVar8);
  }
LAB_0044ac8d:
  iVar4 = FUN_004be560(local_3b8 + 2);
  if (iVar4 == 0) {
    if (aiStack_5d0[3] == 0) {
      Engine_ACTIVATE_COMPANION_4be530(L"[EVILTWIN]",0xffffffff);
      iVar4 = *local_460;
      piVar6 = aiStack_5d0;
      local_4 = CONCAT31(local_4._1_3_,0x13);
      Engine_GET_TEXT_4b4500(piVar6);
      Engine_GET_TEXT_4b4050(piVar6);
      uVar5 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
    }
    else {
      Engine_ACTIVATE_COMPANION_4be530(L"[EVILTWIN]",0xffffffff);
      iVar4 = *local_3b8;
      piVar6 = aiStack_5d0;
      local_4 = CONCAT31(local_4._1_3_,0x14);
      Engine_GET_TEXT_4b4500(piVar6);
      Engine_GET_TEXT_4b4050(piVar6);
      uVar5 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
    }
    (**(code **)(iVar4 + 0x3c))(uVar5);
    local_4 = CONCAT31(local_4._1_3_,0x12);
    Engine_ACTIVATE_COMPANION_4bdf40();
  }
  ppiVar13 = &local_3b8;
  Engine_ADD_GOLD_447c60(ppiVar13);
  FUN_00447cf0(ppiVar13);
  ppiVar13 = &local_460;
  Engine_ADD_GOLD_447c60(ppiVar13);
  FUN_00447cf0(ppiVar13);
  Engine_ADD_GOLD_447c60();
  FUN_00446be0();
  uVar5 = DAT_00583508;
  iVar4 = Engine_EXTRA_TURN_4646e0();
  *(undefined4 *)(iVar4 + 0x34) = uVar5;
  Engine_ADD_GOLD_4046a0();
  local_4 = 0xffffffff;
  Engine_ADD_GOLD_4046a0();
LAB_0044bc62:
  iVar4 = Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
  *(undefined1 *)(iVar4 + 0x393) = 1;
  iVar4 = Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
  *(undefined1 *)(iVar4 + 0x394) = 1;
  iVar4 = Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
  *(undefined1 *)(iVar4 + 0x392) = 1;
  iVar4 = Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
  *(undefined1 *)(iVar4 + 0x391) = 1;
  iVar4 = Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
  *(undefined1 *)(iVar4 + 0x390) = 1;
  iVar4 = Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
  *(undefined1 *)(iVar4 + 0x395) = 1;
  iVar4 = Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
  *(undefined1 *)(iVar4 + 0x396) = 1;
  iVar4 = Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
  *(undefined1 *)(iVar4 + 0x397) = 1;
  CBattleManager_GetSingleton();
  FUN_004411e0();
  Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
  Engine_TUTORIAL_GAME_PLAY_47bd80();
  Engine_EXTRA_TURN_4646e0();
  FUN_00464730();
  FUN_0043b640();
  Engine_EXTRA_TURN_4646e0();
  FUN_00464850();
  uVar5 = 1;
  Engine_ADD_GOLD_447c60(1);
  iVar4 = Engine_ADD_GOLD_446200(uVar5);
  if (*(char *)(iVar4 + 0x10) == '\0') {
    uVar5 = 1;
    Engine_ADD_GOLD_447c60(1);
    piVar6 = (int *)Engine_ADD_GOLD_446200(uVar5);
    if (*(char *)(*piVar6 + 0x26a) != '\0') {
      uVar5 = 5;
      FUN_00457800(5);
      FUN_004570a0(uVar5);
    }
  }
  FUN_00411db0();
  FUN_00407e40();
  Engine_EXTRA_TURN_4646e0();
  FUN_00464be0();
  iVar4 = Engine_EXTRA_TURN_4646e0();
  uVar5 = *(undefined4 *)(iVar4 + 4 + *(int *)(iVar4 + 0x28) * 4);
  uVar14 = uVar5;
  Engine_ADD_GOLD_447c60(uVar5);
  puVar12 = (undefined4 *)Engine_ADD_GOLD_446200(uVar14);
  FUN_0040dde0(&sStack_5c0);
  FUN_0040de40(&sStack_5bc);
  if ((*(char *)(puVar12 + 4) == '\0') || (*(char *)((int)puVar12 + 0x11) == '\0')) {
    uVar14 = 5;
  }
  else {
    uVar14 = 4;
  }
  FUN_004153d0(uVar14,(int)sStack_5c0,(int)sStack_5be,(int)sStack_5bc,(int)sStack_5ba,0x898);
  (**(code **)(*(int *)*puVar12 + 0x20))(4,uVar5,1,0);
  ExceptionList = pvStack_1c;
  FUN_005042e3();
  return;
}

