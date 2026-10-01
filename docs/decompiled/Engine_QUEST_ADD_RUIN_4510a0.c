
void Engine_QUEST_ADD_RUIN_4510a0(undefined4 param_1,undefined4 param_2)

{
  int iVar1;
  
  iVar1 = FUN_00450c00(param_2);
  FUN_00422d00(1);
  FUN_00422d30(1);
  if ((iVar1 != 0) && (*(char *)(iVar1 + 10) != '\0')) {
    FUN_00426b10(&PTR_Rsrc_DATA___GDF_THUMBNAIL_407_130718__005218e4,
                 (int)(short)*(int *)(iVar1 + 0x10),*(int *)(iVar1 + 0x10) >> 0x10);
    Engine_PLAY_SOUND_4b38a0(L"snd_addruin");
  }
  return;
}

