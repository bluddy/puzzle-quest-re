
void Engine_ADD_ANIMEFFECT_TO_CHARACTER_475a10(undefined4 *param_1,int param_2)

{
  int iVar1;
  
  iVar1 = param_2 * 2;
  param_2._0_2_ = (short)*(undefined4 *)(&DAT_0057b1b0 + iVar1);
  param_2._2_2_ = (short)((uint)*(undefined4 *)(&DAT_0057b1b0 + iVar1) >> 0x10);
  param_2 = CONCAT22(param_2._2_2_ + 0x21,(short)param_2 + 0x21);
  *param_1 = param_2;
  return;
}

