
undefined4 Engine_TUTORIAL_GET_HERO_475a90(int param_1)

{
  int iVar1;
  
  if (4 < param_1) {
    return 0xffffffff;
  }
  iVar1 = FUN_004cd860(param_1);
  if (iVar1 == -1) {
    *(undefined4 *)(&DAT_0057b19c + param_1 * 4) = 0xffffffff;
  }
  return *(undefined4 *)(&DAT_0057b19c + param_1 * 4);
}

