
undefined4 Lua_NOTIFY_OF_FREE_SPELL(void)

{
  int iVar1;
  
  iVar1 = Engine_HANDLE_SPELL_COST_4622c0();
  *(undefined1 *)(iVar1 + 0x14) = 1;
  return 0;
}

