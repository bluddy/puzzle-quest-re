
void __fastcall FUN_0047ae80(int param_1)

{
  int iVar1;
  wchar_t *pwVar2;
  undefined4 uVar3;
  undefined4 uVar4;
  wchar_t *pwVar5;
  undefined4 uVar6;
  short local_8;
  short local_6;
  short local_4;
  short local_2;
  
  iVar1 = *(int *)(param_1 + 0x3c8) + 1;
  *(int *)(param_1 + 0x3c8) = iVar1;
  switch(iVar1) {
  case 0:
  case 1:
    goto switchD_0047ae9a_caseD_0;
  case 2:
    pwVar5 = L"snd_cascade1";
    break;
  case 3:
    pwVar5 = L"snd_cascade2";
    break;
  case 4:
    pwVar5 = L"snd_cascade3";
    break;
  case 5:
    pwVar5 = L"snd_cascade4";
    break;
  case 6:
    pwVar5 = L"snd_cascade5";
    break;
  default:
    pwVar5 = L"snd_cascade6";
  }
  Engine_PLAY_SOUND_4b38a0(pwVar5);
switchD_0047ae9a_caseD_0:
  if (*(int *)(param_1 + 0x3c8) == 5) {
    iVar1 = Engine_EXTRA_TURN_4646e0();
    uVar3 = *(undefined4 *)(iVar1 + 4 + *(int *)(iVar1 + 0x28) * 4);
    Engine_ADD_GOLD_447c60(uVar3);
    iVar1 = Engine_ADD_GOLD_446200(uVar3);
    if (*(char *)(iVar1 + 0x10) != '\0') {
      if (*(char *)(iVar1 + 0x11) != '\0') {
        FUN_0040dde0(&local_4);
        FUN_0040de40(&local_8);
        FUN_004156f0(6,(int)local_4,(int)local_2,(int)local_8,(int)local_6,2000);
        Engine_PLAY_SOUND_4b38a0(L"snd_voice_heroiceffort");
        Engine_PLAY_SOUND_4b38a0(L"snd_heroiceffort");
      }
      if (DAT_00580d86 == '\0') {
        if (DAT_005824e6 == '\0') {
          if (DAT_0058159e == '\0') {
            return;
          }
          FUN_0041e7e0();
        }
        else {
          FUN_00438650();
        }
      }
      else {
        Engine_ADD_XP_42c030(100);
      }
      if ((DAT_00580d86 != '\0') && (iVar1 = Engine_GET_GAME_ID_4481d0(), *(int *)(iVar1 + 4) != 4))
      {
        uVar6 = 0;
        uVar4 = 0;
        uVar3 = 0;
        pwVar2 = L"HeroicEffort";
        pwVar5 = L"Help";
        Engine_TUTORIAL_OPEN_4a8600(L"Help",L"HeroicEffort",0,0,0);
        FUN_004a7a50(pwVar5,pwVar2,uVar3,uVar4,uVar6);
      }
    }
  }
  return;
}

