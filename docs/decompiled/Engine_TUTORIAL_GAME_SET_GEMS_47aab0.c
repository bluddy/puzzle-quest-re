
void __thiscall Engine_TUTORIAL_GAME_SET_GEMS_47aab0(int param_1,int param_2,int param_3)

{
  undefined4 *puVar1;
  int iVar2;
  
  iVar2 = 0;
  puVar1 = (undefined4 *)(param_1 + 0xc + param_2 * 8);
  do {
    switch(*(undefined2 *)(param_3 + iVar2 * 2)) {
    case 0x2a:
      *puVar1 = 6;
      break;
    default:
      *puVar1 = 0;
      break;
    case 0x32:
      *puVar1 = 8;
      break;
    case 0x33:
      *puVar1 = 9;
      break;
    case 0x34:
      *puVar1 = 10;
      break;
    case 0x35:
      *puVar1 = 0xb;
      break;
    case 0x36:
      *puVar1 = 0xc;
      break;
    case 0x37:
      *puVar1 = 0xd;
      break;
    case 0x38:
      *puVar1 = 0xe;
      break;
    case 0x42:
      *puVar1 = 4;
      break;
    case 0x47:
      *puVar1 = 1;
      break;
    case 0x4f:
      *puVar1 = 7;
      break;
    case 0x52:
      *puVar1 = 2;
      break;
    case 0x53:
      *puVar1 = 5;
      break;
    case 0x58:
      *puVar1 = 0xf;
      break;
    case 0x59:
      *puVar1 = 3;
    }
    iVar2 = iVar2 + 1;
    puVar1 = puVar1 + 0x12;
  } while (iVar2 < 8);
  return;
}

