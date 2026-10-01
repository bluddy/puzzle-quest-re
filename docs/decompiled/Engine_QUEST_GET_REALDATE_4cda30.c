
void Engine_QUEST_GET_REALDATE_4cda30
               (uint *param_1,uint *param_2,uint *param_3,uint *param_4,uint *param_5,uint *param_6)

{
  _SYSTEMTIME local_10;
  
  GetSystemTime(&local_10);
  *param_1 = (uint)local_10.wYear;
  *param_2 = (uint)local_10.wMonth;
  *param_3 = (uint)local_10.wDay;
  *param_4 = (uint)local_10.wHour;
  *param_5 = (uint)local_10.wMinute;
  *param_6 = (uint)local_10.wSecond;
  return;
}

