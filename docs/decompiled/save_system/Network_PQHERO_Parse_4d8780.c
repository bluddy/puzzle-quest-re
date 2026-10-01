
void Network_PQHERO_Parse_4d8780(void)

{
  wchar_t *pwVar1;
  wchar_t *pwVar2;
  int iVar3;
  size_t sVar4;
  int iVar5;
  undefined4 uVar6;
  wchar_t local_20c [260];
  undefined4 local_4;
  
  local_4 = DAT_0057faa0;
  pwVar1 = wcsstr((wchar_t *)&DAT_005af070,L"TESTCAPTURE:");
  pwVar2 = wcsstr((wchar_t *)&DAT_005af070,L"PQHERO:");
  if (pwVar1 != (wchar_t *)0x0) {
    FUN_0043b640();
    FUN_0043b460();
    FUN_0043ba60();
    uVar6 = 6;
    FUN_00457800(6);
    FUN_004570a0(uVar6);
    DAT_005af280 = (int)(pwVar1 + 0xc);
    DAT_005af27d = 1;
    iVar3 = Engine_GET_GAME_ID_4481d0();
    *(undefined4 *)(iVar3 + 4) = 5;
    Engine_GET_GAME_ID_4481d0();
    FUN_004492f0();
    FUN_005042e3();
    return;
  }
  if (pwVar2 == (wchar_t *)0x0) {
    FUN_0043b050();
    FUN_005042e3();
    return;
  }
  wcscpy(local_20c,pwVar2 + 7);
  iVar3 = 0;
  iVar5 = 0;
  sVar4 = wcslen(local_20c);
  if (0 < (int)sVar4) {
    iVar3 = 0;
    do {
      if (local_20c[iVar5] == L'\\') {
        iVar3 = iVar5 + 1;
      }
      iVar5 = iVar5 + 1;
      sVar4 = wcslen(local_20c);
    } while (iVar5 < (int)sVar4);
  }
  sVar4 = wcslen(local_20c);
  iVar5 = iVar3;
  if (iVar3 < (int)sVar4) {
    do {
      if (local_20c[iVar5] == L'.') {
        local_20c[iVar5] = L'\0';
        break;
      }
      iVar5 = iVar5 + 1;
      sVar4 = wcslen(local_20c);
    } while (iVar5 < (int)sVar4);
  }
  FUN_0043b050();
  FUN_0043b210();
  FUN_00421e60(1);
  FUN_004229d0(local_20c + iVar3);
  FUN_005042e3();
  return;
}

