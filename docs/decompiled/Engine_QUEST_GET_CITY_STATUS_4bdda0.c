
long __fastcall Engine_QUEST_GET_CITY_STATUS_4bdda0(undefined4 *param_1)

{
  long lVar1;
  
  if (param_1[2] == 0) {
    return 0;
  }
  lVar1 = _wtol((wchar_t *)*param_1);
  return lVar1;
}

