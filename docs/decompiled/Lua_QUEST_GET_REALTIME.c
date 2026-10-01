
undefined4 Lua_QUEST_GET_REALTIME(undefined4 param_1)

{
  int local_18;
  int local_14;
  undefined1 local_10 [4];
  undefined1 local_c [4];
  undefined1 local_8 [4];
  undefined1 local_4 [4];
  
  Engine_QUEST_GET_REALDATE_4cda30(local_4,local_8,local_c,&local_18,&local_14,local_10);
  FUN_004f7020(param_1,(double)local_18);
  FUN_004f7020(param_1,(double)local_14);
  return 2;
}

