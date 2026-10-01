
void __thiscall Engine_SUBTRACT_LIFE_466450(int *param_1,undefined4 param_2,undefined4 param_3)

{
  int iVar1;
  int *piVar2;
  int *piVar3;
  
  iVar1 = (**(code **)(*param_1 + 0x20))(0xb,param_2,param_3,param_1[0x11]);
  piVar3 = param_1 + 0x12;
  piVar2 = piVar3;
  Engine_ADD_MAX_LIFE_445030(piVar3);
  Engine_ADD_MAX_LIFE_444d40(piVar2);
  param_1[0x1c] = param_1[0x1c] - iVar1 & (param_1[0x1c] - iVar1 < 1) - 1;
  Engine_ADD_MAX_LIFE_445030(piVar3);
  Engine_ADD_MAX_LIFE_444d80(piVar3);
  iVar1 = param_1[0x11];
  Engine_ADD_GOLD_447c60(iVar1);
  iVar1 = Engine_ADD_GOLD_446200(iVar1);
  if ((((0 < param_1[0x1c]) && (param_1[0x1c] < 0xb)) && (*(char *)(iVar1 + 0x10) != '\0')) &&
     ((*(char *)(iVar1 + 0x11) != '\0' && (*(char *)(iVar1 + 0x24) == '\0')))) {
    *(undefined1 *)(iVar1 + 0x24) = 1;
    Engine_PLAY_SOUND_4b38a0(L"snd_voice_neardeath");
  }
  return;
}

