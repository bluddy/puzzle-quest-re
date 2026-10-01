
void Engine_QUEST_ENCOUNTER_ADD_4511f0(int param_1,undefined4 param_2)

{
  int iVar1;
  
  iVar1 = FUN_00450c00(param_2);
  FUN_00422d00(1);
  FUN_00422d30(1);
  if ((iVar1 != 0) && (*(char *)(iVar1 + 10) != '\0')) {
    if (param_1 == 0) {
      FUN_00426b10(L"NewEncounter",(int)(short)*(int *)(iVar1 + 0x10),*(int *)(iVar1 + 0x10) >> 0x10
                  );
      Engine_PLAY_SOUND_4b38a0(L"snd_addencounter");
    }
    else if (param_1 == 1) {
      FUN_00426b10(L"RemoveEncounter",(int)(short)*(int *)(iVar1 + 0x10),
                   *(int *)(iVar1 + 0x10) >> 0x10);
      Engine_PLAY_SOUND_4b38a0(L"snd_removeencounter");
      return;
    }
  }
  return;
}

