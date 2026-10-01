
char FUN_0047bbb0(void)

{
  short sVar1;
  
  Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
  sVar1 = Engine_GET_RANDOM_4bd280(1,100);
  if (sVar1 < 0x1a) {
    return '\b';
  }
  if (sVar1 < 0x38) {
    return '\t';
  }
  if (sVar1 < 0x4c) {
    return '\n';
  }
  if (sVar1 < 0x58) {
    return '\v';
  }
  if (sVar1 < 0x60) {
    return '\f';
  }
  return (0x62 < sVar1) + '\r';
}

