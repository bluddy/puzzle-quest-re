// refs 0x0043da90 @ 0043eb0a

void __fastcall FUN_0043e5f0(int param_1)

{
  undefined1 uVar1;
  char cVar2;
  int iVar3;
  int *piVar4;
  undefined4 uVar5;
  int iVar6;
  int *piVar7;
  int *piVar8;
  size_t sVar9;
  uint uVar10;
  int iVar11;
  code *pcVar12;
  undefined1 *puVar13;
  wchar_t *pwVar14;
  undefined1 auStack_34c [3];
  char local_349;
  undefined1 local_348 [12];
  undefined4 local_33c;
  int *local_338;
  int *local_334;
  undefined4 uStack_330;
  undefined4 uStack_32c;
  int iStack_328;
  undefined1 auStack_324 [12];
  wchar_t awStack_318 [260];
  wchar_t awStack_110 [128];
  undefined4 local_10;
  void *pvStack_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_005120d7;
  pvStack_c = ExceptionList;
  local_10 = DAT_0057faa0;
  ExceptionList = &pvStack_c;
  iVar3 = FUN_004d1e20();
  local_349 = *(int *)(iVar3 + 0x7c) == 5;
  FUN_0049e6a0();
  iVar3 = Engine_GET_GAME_ID_4481d0();
  iVar3 = *(int *)(iVar3 + 4);
  FUN_0043d580();
  if (iVar3 == 4) {
    FUN_00436730(L"[LOADING]");
    Engine_EXTRA_TURN_4646e0();
    iVar3 = Engine_GET_GAME_ID_4481d0();
    if (*(int *)(iVar3 + 4) == 4) {
      FUN_004d1e20();
      FUN_004d1930();
    }
    FUN_00436780();
  }
  iVar3 = Engine_EXTRA_TURN_4646e0();
  cVar2 = *(char *)(iVar3 + 0x30);
  uVar5 = *(undefined4 *)(param_1 + 0x6c);
  local_33c = CONCAT31(local_33c._1_3_,cVar2);
  Engine_ADD_GOLD_447c60(uVar5);
  local_338 = (int *)Engine_ADD_GOLD_446200(uVar5);
  uVar10 = (uint)(*(int *)(param_1 + 0x6c) == 0);
  Engine_ADD_GOLD_447c60(uVar10);
  local_334 = (int *)Engine_ADD_GOLD_446200(uVar10);
  if (*(char *)(param_1 + 0x70) == '\0') {
    if (local_349 == '\0') {
      piVar4 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"str_title");
      if (cVar2 == '\0') {
        if (piVar4 != (int *)0x0) {
          Engine_ACTIVATE_COMPANION_4be530(L"[DEFEAT]",0xffffffff);
          puVar13 = local_348;
          local_4 = 7;
          Engine_GET_TEXT_4b4500(puVar13);
          Engine_GET_TEXT_4b4050(puVar13);
          uVar5 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
          (**(code **)(*piVar4 + 0x10))(uVar5);
          local_4 = 0xffffffff;
          Engine_ACTIVATE_COMPANION_4bdf40();
        }
        piVar4 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"str_vicgained");
        if (piVar4 != (int *)0x0) {
          Engine_ACTIVATE_COMPANION_4be530(L"[DEFEATGAIN]",0xffffffff);
          puVar13 = local_348;
          local_4 = 8;
          Engine_GET_TEXT_4b4500(puVar13);
          Engine_GET_TEXT_4b4050(puVar13);
          uVar5 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
          (**(code **)(*piVar4 + 0x10))(uVar5);
          local_4 = 0xffffffff;
          Engine_ACTIVATE_COMPANION_4bdf40();
        }
        Engine_PLAY_SOUND_4b38a0(L"snd_defeat");
        Engine_PLAY_SOUND_4b38a0(L"snd_voice_defeat");
        goto LAB_0043ea6a;
      }
      if (piVar4 != (int *)0x0) {
        Engine_ACTIVATE_COMPANION_4be530(L"[VICTORY]",0xffffffff);
        puVar13 = local_348;
        local_4 = 5;
        Engine_GET_TEXT_4b4500(puVar13);
        Engine_GET_TEXT_4b4050(puVar13);
        uVar5 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
        (**(code **)(*piVar4 + 0x10))(uVar5);
        local_4 = 0xffffffff;
        Engine_ACTIVATE_COMPANION_4bdf40();
      }
      piVar4 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"str_vicgained");
      if (piVar4 != (int *)0x0) {
        Engine_ACTIVATE_COMPANION_4be530(L"[VICTORYGAIN]",0xffffffff);
        puVar13 = local_348;
        local_4 = 6;
        Engine_GET_TEXT_4b4500(puVar13);
        Engine_GET_TEXT_4b4050(puVar13);
        uVar5 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
        (**(code **)(*piVar4 + 0x10))(uVar5);
        local_4 = 0xffffffff;
        Engine_ACTIVATE_COMPANION_4bdf40();
      }
      Engine_PLAY_SOUND_4b38a0(L"snd_victory");
      Engine_PLAY_SOUND_4b38a0(L"snd_voice_victory");
      uVar5 = 1;
      goto LAB_0043ea6c;
    }
    if (cVar2 == '\0') {
      if (*(int *)(param_1 + 0x6c) != 1) goto LAB_0043e7b3;
LAB_0043e890:
      piVar4 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"str_title");
      if (piVar4 != (int *)0x0) {
        Engine_ACTIVATE_COMPANION_4be530(L"[PLAYER1WINS]",0xffffffff);
        local_4 = 2;
LAB_0043e7df:
        puVar13 = local_348;
        Engine_GET_TEXT_4b4500(puVar13);
        Engine_GET_TEXT_4b4050(puVar13);
        uVar5 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
        (**(code **)(*piVar4 + 0x10))(uVar5);
        local_4 = 0xffffffff;
        Engine_ACTIVATE_COMPANION_4bdf40();
      }
    }
    else {
      if (*(int *)(param_1 + 0x6c) == 0) goto LAB_0043e890;
LAB_0043e7b3:
      piVar4 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"str_title");
      if (piVar4 != (int *)0x0) {
        Engine_ACTIVATE_COMPANION_4be530(L"[PLAYER2WINS]",0xffffffff);
        local_4 = 3;
        goto LAB_0043e7df;
      }
    }
    piVar4 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"str_vicgained");
    if (piVar4 != (int *)0x0) {
      Engine_ACTIVATE_COMPANION_4be530(L"[MULTIVICTORYGAIN]",0xffffffff);
      puVar13 = local_348;
      local_4 = 4;
      Engine_GET_TEXT_4b4500(puVar13);
      Engine_GET_TEXT_4b4050(puVar13);
      uVar5 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
      (**(code **)(*piVar4 + 0x10))(uVar5);
      local_4 = 0xffffffff;
      Engine_ACTIVATE_COMPANION_4bdf40();
    }
    Engine_PLAY_SOUND_4b38a0(L"snd_victory");
    Engine_PLAY_SOUND_4b38a0(L"snd_voice_victory");
  }
  else {
    piVar4 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"str_title");
    if (piVar4 != (int *)0x0) {
      Engine_ACTIVATE_COMPANION_4be530(L"[DRAWNBATTLE]",0xffffffff);
      puVar13 = local_348;
      local_4 = 0;
      Engine_GET_TEXT_4b4500(puVar13);
      Engine_GET_TEXT_4b4050(puVar13);
      uVar5 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
      (**(code **)(*piVar4 + 0x10))(uVar5);
      local_4 = 0xffffffff;
      Engine_ACTIVATE_COMPANION_4bdf40();
    }
    piVar4 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"str_vicgained");
    if (piVar4 != (int *)0x0) {
      Engine_ACTIVATE_COMPANION_4be530(L"[DRAWNBATTLEGAIN]",0xffffffff);
      puVar13 = local_348;
      local_4 = 1;
      Engine_GET_TEXT_4b4500(puVar13);
      Engine_GET_TEXT_4b4050(puVar13);
      uVar5 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
      (**(code **)(*piVar4 + 0x10))(uVar5);
      local_4 = 0xffffffff;
      Engine_ACTIVATE_COMPANION_4bdf40();
    }
    Engine_PLAY_SOUND_4b38a0(L"snd_defeat");
LAB_0043ea6a:
    uVar5 = 2;
LAB_0043ea6c:
    FUN_00457800(uVar5);
    FUN_004570a0(uVar5);
  }
  DAT_00580e2c = 0;
  iVar3 = *(int *)(*local_338 + 0x94) - local_338[7];
  iVar6 = *(int *)(*local_338 + 0x6c) - local_338[8];
  iVar11 = 0;
  uStack_32c = 0;
  uStack_330 = 0;
  iStack_328 = 0;
  if (local_349 != '\0') {
    iVar11 = *(int *)(*local_334 + 0x94) - local_334[7];
    iStack_328 = *(int *)(*local_334 + 0x6c) - local_334[8];
  }
  if ((char)local_33c == '\0') {
LAB_0043eaf9:
    if (*(char *)(param_1 + 0x70) == '\0') {
      local_334 = (int *)FUN_0043da90(*(undefined4 *)(param_1 + 0x6c));
      goto LAB_0043eb16;
    }
  }
  else if (*(char *)(param_1 + 0x70) == '\0') {
    FUN_0043e400(*(undefined4 *)(param_1 + 0x6c),&uStack_32c,&uStack_330);
    goto LAB_0043eaf9;
  }
  local_334 = (int *)0x0;
LAB_0043eb16:
  if (local_349 == '\0') {
    swprintf(awStack_318,0x52115c,(wchar_t *)(iVar3 - *(int *)(param_1 + 0x88)));
    piVar4 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"str_gold");
    if (piVar4 != (int *)0x0) {
      (**(code **)(*piVar4 + 0x10))(awStack_318);
    }
    swprintf(awStack_318,0x52115c,(wchar_t *)(iVar6 - *(int *)(param_1 + 0x8c)));
    piVar4 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"str_xp");
    pcVar12 = swprintf_exref;
    if (piVar4 != (int *)0x0) {
      (**(code **)(*piVar4 + 0x10))(awStack_318);
      pcVar12 = swprintf_exref;
    }
  }
  else {
    swprintf(awStack_318,0x521164,(wchar_t *)(iVar3 - *(int *)(param_1 + 0x88)),iVar11);
    piVar4 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"str_gold");
    if (piVar4 != (int *)0x0) {
      (**(code **)(*piVar4 + 0x10))(awStack_318);
    }
    pcVar12 = swprintf_exref;
    swprintf(awStack_318,0x521164,(wchar_t *)(iVar6 - *(int *)(param_1 + 0x8c)),iStack_328);
    piVar4 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"str_xp");
    if (piVar4 != (int *)0x0) {
      (**(code **)(*piVar4 + 0x10))(awStack_318);
    }
  }
  piVar4 = local_338;
  *(undefined4 *)(param_1 + 0x74) = uStack_32c;
  *(undefined4 *)(param_1 + 0x78) = uStack_330;
  Engine_ADD_GOLD_42bfc0(uStack_32c);
  Engine_ADD_XP_42c030(*(undefined4 *)(param_1 + 0x78));
  (*pcVar12)(awStack_318,&DAT_0052115c,*(int *)(param_1 + 0x88) + *(int *)(param_1 + 0x74));
  piVar7 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"str_vgold");
  if (piVar7 != (int *)0x0) {
    (**(code **)(*piVar7 + 0x10))(awStack_318);
  }
  (*pcVar12)(awStack_318,&DAT_0052115c,*(int *)(param_1 + 0x8c) + *(int *)(param_1 + 0x78));
  piVar7 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"str_vxp");
  if (piVar7 != (int *)0x0) {
    (**(code **)(*piVar7 + 0x10))(awStack_318);
  }
  FUN_00465fe0(8,0);
  uVar5 = FUN_0050432c();
  *(undefined4 *)(param_1 + 0x7c) = uVar5;
  uVar5 = FUN_0050432c();
  *(undefined4 *)(param_1 + 0x80) = uVar5;
  if ((char)local_33c == '\0') {
    piVar7 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"str_cungained");
    if (piVar7 != (int *)0x0) {
      Engine_ACTIVATE_COMPANION_4be530(L"[CUNNINGDEFEAT]",0xffffffff);
      puVar13 = local_348;
      local_4 = 0xb;
      Engine_GET_TEXT_4b4500(puVar13);
      Engine_GET_TEXT_4b4050(puVar13);
      uVar5 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
      (**(code **)(*piVar7 + 0x10))(uVar5);
      local_4 = 0xffffffff;
      Engine_ACTIVATE_COMPANION_4bdf40();
    }
  }
  else {
    if (local_349 == '\0') {
      Engine_ACTIVATE_COMPANION_4be530(L"[CUNNINGGAIN]",0xffffffff);
      local_4 = 10;
      uVar5 = Engine_ADD_TEMP_SKILL_465f30(5);
      puVar13 = local_348;
      Engine_GET_TEXT_4b4500(puVar13,uVar5);
      Engine_GET_TEXT_4b4050(puVar13);
      uVar5 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
    }
    else {
      Engine_ACTIVATE_COMPANION_4be530(L"[MULTICUNNINGGAIN]",0xffffffff);
      local_4 = 9;
      uVar5 = Engine_ADD_TEMP_SKILL_465f30(5);
      puVar13 = local_348;
      Engine_GET_TEXT_4b4500(puVar13,uVar5);
      Engine_GET_TEXT_4b4050(puVar13);
      uVar5 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
    }
    (*pcVar12)(awStack_318,uVar5);
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    piVar7 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"str_cungained");
    if (piVar7 != (int *)0x0) {
      (**(code **)(*piVar7 + 0x10))(awStack_318);
    }
    Engine_ADD_GOLD_42bfc0(*(undefined4 *)(param_1 + 0x7c));
    Engine_ADD_XP_42c030(*(undefined4 *)(param_1 + 0x80));
  }
  (*pcVar12)(awStack_318,&DAT_0052115c,*(undefined4 *)(param_1 + 0x7c));
  piVar7 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"str_cgold");
  if (piVar7 != (int *)0x0) {
    (**(code **)(*piVar7 + 0x10))(awStack_318);
  }
  (*pcVar12)(awStack_318,&DAT_0052115c,*(undefined4 *)(param_1 + 0x80));
  piVar7 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"str_cxp");
  if (piVar7 != (int *)0x0) {
    (**(code **)(*piVar7 + 0x10))(awStack_318);
  }
  iVar3 = FUN_0043dd10(*(undefined4 *)(param_1 + 0x6c));
  uVar5 = local_33c;
  if (iVar3 != 0) {
    if (((char)local_33c != '\0') && (*(char *)(param_1 + 0x70) == '\0')) {
      FUN_00467a00(1);
    }
    FUN_0046c670(iVar3,uVar5);
  }
  iVar6 = 0;
  Engine_ADD_GOLD_447c60();
  iVar3 = FUN_00445db0();
  if (0 < iVar3) {
    do {
      if (iVar6 != *(int *)(param_1 + 0x6c)) {
        iVar3 = iVar6;
        Engine_ADD_GOLD_447c60(iVar6);
        iVar3 = Engine_ADD_GOLD_446200(iVar3);
        if (((*(char *)(iVar3 + 0x10) != '\0') && (*(char *)(param_1 + 0x70) == '\0')) &&
           ((uint)(*(int *)(iVar3 + 0xc) == piVar4[3]) == (int)(char)local_33c)) {
          FUN_00467a00(1);
        }
      }
      iVar6 = iVar6 + 1;
      Engine_ADD_GOLD_447c60();
      iVar3 = FUN_00445db0();
    } while (iVar6 < iVar3);
  }
  iVar3 = *piVar4;
  Engine_GET_GAME_ID_4481d0(iVar3,uVar5);
  FUN_00448380(iVar3,uVar5);
  Engine_QUEST_ADD_ITEM_4b1590();
  piVar7 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"butt_continue");
  piVar8 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"gp_continue");
  uVar1 = FUN_0046ecd0();
  *(undefined1 *)(param_1 + 0x71) = uVar1;
  if (local_349 != '\0') {
    *(undefined1 *)(param_1 + 0x71) = 0;
  }
  *(undefined1 *)(param_1 + 0x90) = 0;
  if (*(char *)(param_1 + 0x71) == '\0') {
    piVar4 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"str_levelup");
    if (piVar4 != (int *)0x0) {
      (**(code **)(*piVar4 + 0x10))(&DAT_0051b07c);
    }
    if ((piVar7 != (int *)0x0) && (piVar8 != (int *)0x0)) {
      Engine_ACTIVATE_COMPANION_4be530(L"[CONTINUE]",0xffffffff);
      puVar13 = local_348;
      local_4 = 0xf;
      Engine_GET_TEXT_4b4500(puVar13);
      Engine_GET_TEXT_4b4050(puVar13);
      uVar5 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
      (**(code **)(*piVar7 + 0x10))(uVar5);
      puStack_8 = (undefined1 *)0xffffffff;
      Engine_ACTIVATE_COMPANION_4bdf40();
      Engine_ACTIVATE_COMPANION_4be530(L"[CONTINUE]",0xffffffff);
      puVar13 = auStack_34c;
      puStack_8 = (undefined1 *)0x10;
      Engine_GET_TEXT_4b4500(puVar13);
      Engine_GET_TEXT_4b4050(puVar13);
      uVar5 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
      (**(code **)(*piVar8 + 0x10))(uVar5);
      local_4 = 0xffffffff;
      Engine_ACTIVATE_COMPANION_4bdf40();
    }
  }
  else {
    local_338 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"str_levelup");
    if (local_338 != (int *)0x0) {
      Engine_ACTIVATE_COMPANION_4be530(L"[GAINEDLEVEL]",0xffffffff);
      puVar13 = local_348;
      local_4 = 0xc;
      Engine_GET_TEXT_4b4500(puVar13);
      Engine_GET_TEXT_4b4050(puVar13);
      uVar5 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
      (**(code **)(*local_338 + 0x10))(uVar5);
      local_4 = 0xffffffff;
      Engine_ACTIVATE_COMPANION_4bdf40();
    }
    if ((piVar7 != (int *)0x0) && (piVar8 != (int *)0x0)) {
      Engine_ACTIVATE_COMPANION_4be530(L"[LEVELUP]",0xffffffff);
      puVar13 = local_348;
      local_4 = 0xd;
      Engine_GET_TEXT_4b4500(puVar13);
      Engine_GET_TEXT_4b4050(puVar13);
      uVar5 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
      (**(code **)(*piVar7 + 0x10))(uVar5);
      puStack_8 = (undefined1 *)0xffffffff;
      Engine_ACTIVATE_COMPANION_4bdf40();
      Engine_ACTIVATE_COMPANION_4be530(L"[LEVELUP]",0xffffffff);
      puVar13 = auStack_34c;
      puStack_8 = (undefined1 *)0xe;
      Engine_GET_TEXT_4b4500(puVar13);
      Engine_GET_TEXT_4b4050(puVar13);
      uVar5 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
      (**(code **)(*piVar8 + 0x10))(uVar5);
      local_4 = 0xffffffff;
      Engine_ACTIVATE_COMPANION_4bdf40();
    }
    iVar3 = *piVar4;
    uVar5 = *(undefined4 *)(iVar3 + 0x68);
    iVar6 = (int)*(short *)(iVar3 + 0x1bd);
    FUN_00459730(iVar6,uVar5);
    iVar6 = FUN_004589a0(iVar6,uVar5);
    if (((-1 < iVar6) && (*(int *)(iVar3 + 0xe8) != 0)) &&
       ((*(int *)(iVar3 + 0xec) - *(int *)(iVar3 + 0xe8)) / 0xc == 7)) {
      *(undefined1 *)(param_1 + 0x90) = 1;
    }
    Engine_QUEST_ADD_ITEM_4b1590();
  }
  FUN_0043d970();
  *(int **)(param_1 + 0x84) = local_334;
  if (*(char *)(param_1 + 0x70) == '\0') {
    Engine_ACTIVATE_COMPANION_4be530(L"[ACCESSING_HISCORES]",0xffffffff);
    puVar13 = local_348;
    local_4 = 0x12;
    Engine_GET_TEXT_4b4500(puVar13);
    Engine_GET_TEXT_4b4050(puVar13);
    uVar5 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
    FUN_00436730(uVar5);
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    FUN_004b4d40();
    cVar2 = FUN_0043e060();
    if (cVar2 == '\0') {
      Engine_ACTIVATE_COMPANION_4be530(L"[SCORE_N]",0xffffffff);
      pwVar14 = *(wchar_t **)(param_1 + 0x84);
      puVar13 = auStack_324;
      local_4 = 0x14;
      Engine_GET_TEXT_4b4500(puVar13);
      Engine_GET_TEXT_4b4050(puVar13);
      sVar9 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
      swprintf(awStack_110,sVar9,pwVar14);
    }
    else {
      Engine_ACTIVATE_COMPANION_4be530(L"[NEWHIGHSCORE_N]",0xffffffff);
      pwVar14 = *(wchar_t **)(param_1 + 0x84);
      puVar13 = local_348;
      local_4 = 0x13;
      Engine_GET_TEXT_4b4500(puVar13);
      Engine_GET_TEXT_4b4050(puVar13);
      sVar9 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
      swprintf(awStack_110,sVar9,pwVar14);
    }
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    piVar4 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"str_score");
    if (piVar4 != (int *)0x0) {
      (**(code **)(*piVar4 + 0x10))(awStack_110);
    }
    FUN_00436780();
  }
  else {
    piVar4 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"str_score");
    if (piVar4 != (int *)0x0) {
      Engine_ACTIVATE_COMPANION_4be530(L"[DRAWNBATTLEDESC]",0xffffffff);
      puVar13 = local_348;
      local_4 = 0x11;
      Engine_GET_TEXT_4b4500(puVar13);
      Engine_GET_TEXT_4b4050(puVar13);
      uVar5 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
      (**(code **)(*piVar4 + 0x10))(uVar5);
      local_4 = 0xffffffff;
      Engine_ACTIVATE_COMPANION_4bdf40();
    }
  }
  ExceptionList = pvStack_c;
  FUN_005042e3();
  return;
}

