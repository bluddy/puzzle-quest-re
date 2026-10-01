// refs 0x0043f870 @ 0047c834

undefined4 __fastcall FUN_0047c830(int param_1)

{
  int iVar1;
  wchar_t *pwVar2;
  wchar_t *pwVar3;
  undefined4 uVar4;
  undefined4 uVar5;
  undefined4 uVar6;
  
  iVar1 = CBattleManager_GetSingleton();
  CBattleManager_EvaluateBoard();
  if (*(char *)(iVar1 + 0x2c) == '\0') {
    iVar1 = Engine_GET_GAME_ID_4481d0();
    if (*(int *)(iVar1 + 0x20) == 2) {
      Engine_EXTRA_TURN_4646e0();
      FUN_004648f0();
    }
    else {
      *(undefined4 *)(param_1 + 0x34c) = 6;
    }
    FUN_0040f560();
    if (DAT_00580d86 != '\0') {
      iVar1 = Engine_GET_GAME_ID_4481d0();
      if ((*(int *)(iVar1 + 4) != 4) && (*(int *)(param_1 + 0x34c) == 6)) {
        uVar6 = 0;
        uVar5 = 0;
        uVar4 = 0;
        pwVar3 = L"ManaDrain";
        pwVar2 = L"Help";
        Engine_TUTORIAL_OPEN_4a8600(L"Help",L"ManaDrain",0,0,0);
        FUN_004a7a50(pwVar2,pwVar3,uVar4,uVar5,uVar6);
      }
    }
    return 1;
  }
  return 0;
}

