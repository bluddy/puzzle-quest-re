
int Engine_SET_GAMEPAD_OBJECT_4c1dc0(wchar_t *param_1)

{
  int iVar1;
  wchar_t *_Str1;
  int iVar2;
  wchar_t *_Str2;
  
  if (DAT_0059a500 != (int *)0x0) {
    iVar1 = *DAT_0059a500;
    DAT_0059a504 = DAT_0059a500;
    while (iVar1 != 0) {
      _Str2 = param_1;
      _Str1 = (wchar_t *)Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
      iVar2 = _wcsicmp(_Str1,_Str2);
      if (iVar2 == 0) {
        return iVar1;
      }
      if (DAT_0059a4d0 != '\0') {
        return 0;
      }
      if (DAT_0059a504 == (int *)0x0) {
        return 0;
      }
      if (*(char *)(*DAT_0059a504 + 0x1e) == '\0') {
        return 0;
      }
      DAT_0059a504 = (int *)DAT_0059a504[1];
      if (DAT_0059a504 == (int *)0x0) {
        return 0;
      }
      DAT_0059a4d0 = '\0';
      iVar1 = *DAT_0059a504;
    }
  }
  return 0;
}

