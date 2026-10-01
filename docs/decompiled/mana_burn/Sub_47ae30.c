
void __thiscall FUN_0047ae30(int param_1,int param_2)

{
  undefined4 uVar1;
  int iVar2;
  
  Engine_PLAY_SOUND_4b38a0(L"snd_aispell");
  *(int *)(param_1 + 0x36c) = param_2 + 1000;
  iVar2 = CBattleManager_GetSingleton();
  uVar1 = *(undefined4 *)(iVar2 + 0x44);
  iVar2 = Engine_EXTRA_TURN_4646e0();
  FUN_00415dd0(*(undefined4 *)(iVar2 + 4 + *(int *)(iVar2 + 0x28) * 4),uVar1);
  return;
}

