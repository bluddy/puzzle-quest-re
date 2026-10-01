
/* WARNING: Function: __chkstk replaced with injection: alloca_probe */
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void __thiscall
FUN_0047d4f0(int param_1,int param_2,int *param_3,undefined4 param_4,undefined4 param_5,
            float param_6,int param_7,undefined4 param_8,int param_9)

{
  undefined1 uVar1;
  undefined1 uVar2;
  undefined1 uVar3;
  wchar_t *_Format;
  int iVar4;
  undefined4 *puVar5;
  int *piVar6;
  int iVar7;
  int iVar8;
  int iVar9;
  undefined1 *puVar10;
  short *psVar11;
  int iVar12;
  undefined4 uVar13;
  undefined4 uVar14;
  int local_1538;
  char *local_1530;
  undefined1 uStack_1521;
  int iStack_1520;
  int local_151c;
  int iStack_1518;
  undefined1 auStack_1514 [12];
  int iStack_1508;
  undefined4 uStack_1504;
  wchar_t local_1500 [16];
  undefined1 auStack_14e0 [8];
  undefined1 auStack_14d8 [5320];
  undefined4 local_10;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 uStack_4;
  
  uStack_4 = 0xffffffff;
  puStack_8 = &LAB_00515296;
  local_c = ExceptionList;
  local_10 = DAT_0057faa0;
  ExceptionList = &local_c;
  local_151c = param_1;
  Engine_ADD_GOLD_447c60();
  _Format = (wchar_t *)param_3[param_2 * 7 + 5];
  if ((int)_Format < 1) goto LAB_0047db85;
  if (param_6 != _DAT_0051e39c) {
    _Format = (wchar_t *)FUN_0050432c();
  }
  iVar4 = Engine_EXTRA_TURN_4646e0();
  puVar5 = (undefined4 *)
           Engine_ADD_GOLD_446200(*(undefined4 *)(iVar4 + 4 + *(int *)(iVar4 + 0x28) * 4));
  if (*(char *)(param_1 + 0x396) != '\0') {
    iVar4 = Engine_GET_GAME_ID_4481d0();
    if (*(int *)(iVar4 + 0x20) == 6) {
      if (3 < param_2) {
        if (param_2 < 7) {
LAB_0047d631:
          param_7 = -1;
          FUN_004c62f0(0x3e99999a,500);
          goto LAB_0047d749;
        }
        if (param_2 == 8) {
          FUN_00439410(4,_Format);
          FUN_004c62f0(0x3f4ccccd,500);
          goto LAB_0047d749;
        }
      }
      FUN_00439410(param_4,_Format);
      FUN_004c62f0(0x3e99999a,500);
    }
    else {
      iVar4 = Engine_GET_GAME_ID_4481d0();
      if (*(int *)(iVar4 + 0x20) == 5) {
        if (param_2 != 9) goto LAB_0047d631;
        FUN_0041f620(_Format);
        FUN_004c62f0(0x3f4ccccd,500);
      }
      else {
        local_1538 = 0;
        iVar4 = FUN_004469c0(param_3[param_2 * 7 + 4]);
        if (0 < iVar4) {
          do {
            iVar4 = FUN_00446a60(param_3[param_2 * 7 + 4],local_1538);
            if (param_2 == 4) {
              _Format = (wchar_t *)
                        (**(code **)(*(int *)*puVar5 + 0x1c))
                                  (_Format,puVar5[2],*(undefined4 *)(iVar4 + 8));
              uVar13 = 0x3f000000;
            }
            else if (param_2 == 5) {
              Engine_ADD_GOLD_42bfc0(_Format);
              uVar13 = 0x3e99999a;
            }
            else if (param_2 == 6) {
              Engine_ADD_XP_42c030(_Format);
              uVar13 = 0x3e99999a;
            }
            else {
              Engine_ADD_MANA_AIR_47a660(param_4,_Format);
              uVar13 = 0x3e99999a;
            }
            FUN_004c62f0(uVar13,500);
            local_1538 = local_1538 + 1;
            iVar4 = FUN_004469c0(param_3[param_2 * 7 + 4]);
          } while (local_1538 < iVar4);
        }
      }
    }
  }
LAB_0047d749:
  piVar6 = (int *)FUN_004b2ba0(param_5);
  if (piVar6 != (int *)0x0) {
    (**(code **)(*piVar6 + 0x28))();
  }
  if ((param_7 != -1) && (*(char *)(param_1 + 0x396) != '\0')) {
    swprintf(local_1500,0x523594,_Format);
    FUN_00415640(local_1500,param_7,param_8,param_9,param_8,param_9 + 0x50,0xa28);
  }
  if (*(char *)(param_1 + 0x391) != '\0') {
    iVar4 = FUN_004bd1f0(1,100,0);
    iVar7 = FUN_0050432c();
    if ((iVar4 < iVar7) && (iVar4 = Engine_EXTRA_TURN_4646e0(), *(char *)(iVar4 + 0x32) == '\0')) {
      uVar14 = 1;
      uVar13 = 1;
      Engine_EXTRA_TURN_4646e0(1,1);
      Engine_EXTRA_TURN_464cb0(uVar13,uVar14);
      Engine_PLAY_SOUND_4b38a0(L"snd_extraturn");
      Engine_ACTIVATE_COMPANION_4be530(L"[EXTRATURN]",0xffffffff);
      puVar10 = auStack_1514;
      uStack_4 = 0;
      Engine_GET_TEXT_4b4500(puVar10,param_7,param_8,param_9,param_8,param_9 + -0x28,0xa28);
      Engine_GET_TEXT_4b4050(puVar10);
      uVar13 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
      FUN_00415640(uVar13);
      uStack_4 = 0xffffffff;
      Engine_ACTIVATE_COMPANION_4bdf40();
    }
  }
  if ((*(char *)(param_1 + 0x390) != '\0') && (param_3[3] < 5)) {
    iVar4 = FUN_004bd1f0(1,100,0);
    iVar7 = FUN_0050432c();
    if ((iVar4 < iVar7) &&
       (iVar4 = ((uint)((char)param_3[2] == '\0') + (uint)((char)param_3[2] != '\0') * 9) *
                (param_3[3] / 2),
       *(int *)(param_1 + 4 + (iVar4 + *param_3 * 9 + param_3[1]) * 8) == 0)) {
      uVar13 = FUN_0047bbb0();
      *(undefined4 *)(param_1 + 4 + (iVar4 + *param_3 * 9 + param_3[1]) * 8) = uVar13;
      Engine_ACTIVATE_COMPANION_4be530(L"[WILDCARD]",0xffffffff);
      puVar10 = auStack_1514;
      uStack_4 = 1;
      Engine_GET_TEXT_4b4500(puVar10,param_7,param_8,param_9 + -0x20,param_8,param_9 + -0x50,0xa28);
      Engine_GET_TEXT_4b4050(puVar10);
      uVar13 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
      FUN_00415640(uVar13);
      uStack_4 = 0xffffffff;
      Engine_ACTIVATE_COMPANION_4bdf40();
    }
  }
  if (param_2 == 7) {
    FUN_004c62f0(0x3f800000,500);
    uVar1 = *(undefined1 *)(param_1 + 0x390);
    uVar2 = *(undefined1 *)(param_1 + 0x391);
    uVar3 = *(undefined1 *)(param_1 + 0x392);
    iVar4 = 0;
    *(undefined1 *)(param_1 + 0x390) = 0;
    *(undefined1 *)(param_1 + 0x391) = 0;
    *(undefined1 *)(param_1 + 0x392) = 0;
    local_1538 = 0;
    iVar7 = 0x12;
    do {
      FUN_0043fc10();
      iVar7 = iVar7 + -1;
    } while (iVar7 != 0);
    iStack_1520 = 0;
    if (0 < param_3[0x36]) {
      psVar11 = (short *)((int)param_3 + 0xde);
      do {
        iVar8 = (int)psVar11[-1];
        iVar7 = *psVar11 + 1;
        iVar9 = *psVar11 + -1;
        iStack_1518 = iVar7;
        iStack_1508 = iVar8;
        if (iVar9 <= iVar7) {
          do {
            if (((0 < iVar9) && (iVar9 < 9)) && (iVar12 = iVar8 + -1, iVar12 <= iVar8 + 1)) {
              iVar7 = iVar9 + iVar12 * 9;
              local_1530 = (char *)(iVar7 + 0x3e4 + param_1);
              puVar10 = auStack_14d8 + iVar4 * 0x128;
              piVar6 = (int *)(param_1 + 4 + iVar7 * 8);
              do {
                if (((-1 < iVar12) && (iVar12 < 8)) && ((*piVar6 != 0 && (*local_1530 == '\0')))) {
                  *puVar10 = 1;
                  *(undefined4 *)(puVar10 + 4) = 1;
                  uStack_1504 = 1;
                  *(int *)(puVar10 + -8) = iVar12;
                  *(int *)(puVar10 + -4) = iVar9;
                  FUN_0047b0c0(*piVar6,iVar12,iVar9,puVar10 + -8,&uStack_1521,&uStack_1504);
                  local_1538 = local_1538 + 1;
                  puVar10 = puVar10 + 0x128;
                  *piVar6 = 0;
                  iVar8 = iStack_1508;
                }
                local_1530 = local_1530 + 9;
                iVar12 = iVar12 + 1;
                piVar6 = piVar6 + 0x12;
                iVar7 = iStack_1518;
                param_1 = local_151c;
                iVar4 = local_1538;
              } while (iVar12 <= iVar8 + 1);
            }
            iVar9 = iVar9 + 1;
          } while (iVar9 <= iVar7);
        }
        iStack_1520 = iStack_1520 + 1;
        psVar11 = psVar11 + 2;
      } while (iStack_1520 < param_3[0x36]);
    }
    if (0 < iVar4) {
      puVar10 = auStack_14e0;
      do {
        FUN_0047cd90(puVar10);
        puVar10 = puVar10 + 0x128;
        iVar4 = iVar4 + -1;
      } while (iVar4 != 0);
    }
    *(undefined1 *)(param_1 + 0x390) = uVar1;
    *(undefined1 *)(param_1 + 0x391) = uVar2;
    *(undefined1 *)(param_1 + 0x392) = uVar3;
  }
LAB_0047db85:
  ExceptionList = local_c;
  FUN_005042e3();
  return;
}

