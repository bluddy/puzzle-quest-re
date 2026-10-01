// refs 0x0043f870 @ 0047dc6d

void __thiscall FUN_0047dc30(int param_1,int param_2,int param_3,int param_4,int param_5)

{
  char cVar1;
  int iVar2;
  wchar_t *pwVar3;
  undefined4 uVar4;
  int *piVar5;
  undefined4 *puVar6;
  int iVar7;
  int iVar8;
  int iVar9;
  undefined1 *puVar10;
  undefined **ppuVar11;
  int iVar12;
  int iVar13;
  undefined4 uVar14;
  undefined4 uVar15;
  undefined4 local_5c;
  undefined4 local_58;
  undefined1 auStack_44 [12];
  wchar_t awStack_38 [20];
  undefined4 local_10;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  iVar7 = param_5;
  iVar8 = param_4;
  local_4 = 0xffffffff;
  puStack_8 = &LAB_005152dc;
  local_c = ExceptionList;
  local_10 = DAT_0057faa0;
  ExceptionList = &local_c;
  iVar2 = param_2;
  iVar9 = param_3;
  iVar12 = param_4;
  iVar13 = param_5;
  CBattleManager_GetSingleton(param_2,param_3,param_4,param_5);
  cVar1 = FUN_0043fcb0(iVar2,iVar9,iVar12,iVar13);
  if (cVar1 == '\0') {
    iVar2 = Engine_GET_GAME_ID_4481d0();
    if (*(int *)(iVar2 + 0x20) == 4) {
      *(undefined1 *)(param_1 + 0x368) = 1;
    }
    iVar2 = FUN_004f0184(0x44);
    local_4 = 3;
    if (iVar2 == 0) {
      local_5c = 0;
    }
    else {
      local_5c = FUN_00479d70(param_2,param_3,iVar8,iVar7,0);
    }
    local_4 = 0xffffffff;
    iVar2 = FUN_004f0184(0x44);
    local_4 = 4;
    if (iVar2 == 0) {
      uVar4 = 0;
    }
    else {
      uVar4 = FUN_00479d70(iVar8,iVar7,param_2,param_3,0);
    }
    local_4 = 0xffffffff;
    FUN_0047a470(local_5c);
    FUN_0047a570(local_5c);
    FUN_0047a470(uVar4);
    FUN_0047a570(uVar4);
    piVar5 = (int *)FUN_004b2ba0(L"snd_illegal");
    if (piVar5 != (int *)0x0) {
      (**(code **)(*piVar5 + 0x28))();
    }
    if (*(char *)(param_1 + 0x397) != '\0') {
      piVar5 = (int *)FUN_004b2ba0(L"snd_damage");
      if (piVar5 != (int *)0x0) {
        (**(code **)(*piVar5 + 0x28))();
      }
      uVar14 = 0;
      uVar4 = 0;
      Engine_ADD_GOLD_447c60(0,0);
      puVar6 = (undefined4 *)FUN_00446a60(uVar4,uVar14);
      pwVar3 = (wchar_t *)(**(code **)(*(int *)*puVar6 + 0x1c))(5,puVar6[2],puVar6[2]);
      iVar8 = *(int *)(param_1 + 0x3cc) + param_2 * 0x4a + 0x24;
      iVar7 = *(int *)(param_1 + 0x3d0) + param_3 * 0x4a + -0x26;
      cVar1 = FUN_0040f510(7,&param_4,&param_5);
      if (cVar1 != '\0') {
        FUN_00415790(6,iVar8,iVar7,param_4,param_5,500);
      }
      swprintf(awStack_38,0x51d174,pwVar3);
      FUN_00415640(awStack_38,6,iVar8,iVar7,iVar8,iVar7 + 0x50,0xa28);
      Engine_ACTIVATE_COMPANION_4be530(L"[ILLEGALMOVE]",0xffffffff);
      puVar10 = auStack_44;
      local_4 = 5;
      Engine_GET_TEXT_4b4500(puVar10,6,iVar8,iVar7 + -0x14,iVar8,iVar7 + -0x28,0xa28);
      Engine_GET_TEXT_4b4050(puVar10);
      uVar4 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
      FUN_00415640(uVar4);
      local_4 = 0xffffffff;
      Engine_ACTIVATE_COMPANION_4bdf40();
    }
    if (DAT_00580d86 != '\0') {
      iVar8 = Engine_GET_GAME_ID_4481d0();
      if (*(int *)(iVar8 + 4) != 4) {
        iVar8 = Engine_TUTORIAL_OPEN_4a8600();
        uVar15 = 0;
        uVar14 = 0;
        uVar4 = 0;
        if (*(char *)(iVar8 + 0x14) == '\0') {
          ppuVar11 = &PTR_Rsrc_DATA___GDF_THUMBNAIL_40a_124881__0052359c;
        }
        else {
          ppuVar11 = &PTR_Rsrc_DATA___GDF_THUMBNAIL_40a_124881__005235b8;
        }
        pwVar3 = L"Help";
        Engine_TUTORIAL_OPEN_4a8600(L"Help",ppuVar11,0,0,0);
        FUN_004a7a50(pwVar3,ppuVar11,uVar4,uVar14,uVar15);
      }
    }
  }
  else {
    iVar2 = FUN_004f0184(0x34);
    local_4 = 0;
    if (iVar2 == 0) {
      local_58 = 0;
    }
    else {
      local_58 = FUN_00479bc0(param_2,param_3,iVar8,iVar7,1);
    }
    local_4 = 0xffffffff;
    iVar2 = FUN_004f0184(0x34);
    local_4 = 1;
    if (iVar2 == 0) {
      local_5c = 0;
    }
    else {
      local_5c = FUN_00479bc0(iVar8,iVar7,param_2,param_3,0);
    }
    local_4 = 0xffffffff;
    FUN_0047a470(local_58);
    FUN_0047a570(local_58);
    FUN_0047a470(local_5c);
    FUN_0047a570(local_5c);
    Engine_EXTRA_TURN_4646e0();
    cVar1 = FUN_00464b70();
    pwVar3 = L"SwapGemAI";
    if (cVar1 != '\0') {
      pwVar3 = L"SwapGem";
    }
    Engine_ACTIVATE_COMPANION_4be530(pwVar3,0xffffffff);
    iVar2 = param_3 * 0x4a + 0x2f;
    iVar9 = param_2 * 0x4a + 0x29;
    local_4 = 2;
    uVar4 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(iVar9,iVar2);
    Engine_ADD_ANIMEFFECT_TO_GRID_483380(uVar4);
    Engine_ADD_ANIMEFFECT_TO_GRID_483560(uVar4,iVar9,iVar2);
    iVar7 = iVar7 * 0x4a + 0x2f;
    iVar8 = iVar8 * 0x4a + 0x29;
    uVar4 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(iVar8,iVar7);
    Engine_ADD_ANIMEFFECT_TO_GRID_483380(uVar4);
    Engine_ADD_ANIMEFFECT_TO_GRID_483560(uVar4,iVar8,iVar7);
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
  }
  Engine_TUTORIAL_GAME_PLAY_47bf10();
  ExceptionList = local_c;
  FUN_005042e3();
  return;
}

