
undefined4 __thiscall Engine_ADD_EFFECT_TO_GRID_4b51d0(int param_1,int param_2)

{
  if (param_2 == -1) {
    param_2 = (int)*(short *)(param_1 + 0x58);
  }
  switch(param_2) {
  case 1:
  case 7:
  case 0xc:
  case 0x10:
    return 2;
  default:
    return 0;
  case 8:
  case 0xb:
  case 0xd:
  case 0xf:
  case 0x11:
    return 3;
  }
}

