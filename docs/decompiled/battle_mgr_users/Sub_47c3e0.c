// refs 0x0043f870 @ 0047c407

void __fastcall FUN_0047c3e0(int param_1)

{
  char cVar1;
  int iVar2;
  int iVar3;
  wchar_t *pwVar4;
  short *psVar5;
  short *psVar6;
  short local_8;
  short local_6;
  short local_4;
  short local_2;
  
  iVar2 = Engine_EXTRA_TURN_4646e0();
  iVar3 = DAT_0057f484;
  if (*(char *)(iVar2 + 0x31) == '\0') {
    iVar2 = *(int *)(param_1 + 0x354);
    if (iVar2 == 0) {
      CBattleManager_GetSingleton();
      cVar1 = FUN_00440fb0();
      if (cVar1 == '\0') {
        CBattleManager_GetSingleton();
        CBattleManager_EvaluateBoard();
        *(undefined4 *)(param_1 + 0x354) = 2;
        return;
      }
      *(undefined4 *)(param_1 + 0x354) = 1;
      FUN_0047ae30(iVar3);
      return;
    }
    if (iVar2 == 1) {
      if (*(int *)(param_1 + 0x36c) < DAT_0057f484) {
        CBattleManager_GetSingleton();
        FUN_0043fe30();
        *(undefined4 *)(param_1 + 0x354) = 3;
        return;
      }
    }
    else if (iVar2 == 2) {
      if (*(char *)(param_1 + 0x369) == '\0') {
        local_8 = -1;
        local_6 = -1;
        local_4 = -1;
        local_2 = -1;
        psVar6 = &local_4;
        psVar5 = &local_8;
        iVar3 = DAT_0057f484 + 1000;
        *(undefined1 *)(param_1 + 0x369) = 1;
        *(int *)(param_1 + 0x36c) = iVar3;
        CBattleManager_GetSingleton(psVar5,psVar6);
        FUN_0043f920(psVar5,psVar6);
        iVar3 = local_6 * 0x4a + 0x2f;
        iVar2 = local_8 * 0x4a + 0x29;
        pwVar4 = L"MoveGemAI_0";
        Engine_ADD_ANIMEFFECT_TO_GRID_483380(L"MoveGemAI_0",iVar2,iVar3);
        Engine_ADD_ANIMEFFECT_TO_GRID_483560(pwVar4,iVar2,iVar3);
        iVar3 = local_2 * 0x4a + 0x2f;
        iVar2 = local_4 * 0x4a + 0x29;
        pwVar4 = L"MoveGemAI_1";
        Engine_ADD_ANIMEFFECT_TO_GRID_483380(L"MoveGemAI_1",iVar2,iVar3);
        Engine_ADD_ANIMEFFECT_TO_GRID_483560(pwVar4,iVar2,iVar3);
        return;
      }
      if (*(int *)(param_1 + 0x36c) < DAT_0057f484) {
        *(undefined1 *)(param_1 + 0x369) = 0;
        *(undefined4 *)(param_1 + 0x354) = 3;
        return;
      }
    }
    else if (iVar2 == 3) {
      CBattleManager_GetSingleton();
      cVar1 = FUN_0043faf0();
      *(undefined4 *)(param_1 + 0x354) = 0;
      *(uint *)(param_1 + 0x34c) = (cVar1 != '\0') + 1;
    }
  }
  return;
}

