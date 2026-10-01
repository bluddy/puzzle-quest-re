
undefined4 Lua_NOTIFY_OF_ACTIVATED_ITEM(void)

{
  int iVar1;
  
  iVar1 = Engine_GET_CURRENT_RUNE_CODE_44f8e0();
  *(undefined1 *)(iVar1 + 0x14) = 1;
  return 0;
}

