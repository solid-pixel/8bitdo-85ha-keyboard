#ifndef BD85_MAPPING_H
#define BD85_MAPPING_H
#include <stdint.h>
#include <string.h>
static inline int physical_key(unsigned int key) {
 return (key>=4 && key<=0x52 && key!=0x32) || (key>=0x64 && key<=0x6a);
}
static inline int media_usage(unsigned int usage) {
 switch(usage){case 0x6f:case 0x70:case 0xb5:case 0xb6:case 0xb7:case 0xcd:case 0xe2:case 0xe9:case 0xea:return 1;default:return 0;}
}
static inline void default_mapping(unsigned int key,uint8_t out[24]) {
 memset(out,0,24);out[0]=7;
 if(key>=0x64 && key<=0x6a)out[1]=(uint8_t)(0xe0+key-0x64);
 else out[2]=(uint8_t)key;
}
static inline int mapping_valid(const uint8_t *data) {
 for(int i=3;i<24;i++)if(data[i])return 0;
 if(data[0]==7)return (data[1]==0 || (data[1]>=0xe0 && data[1]<=0xe7)) && (data[2]==0 || (data[2]>=4 && data[2]<=0x73));
 return data[0]==12 && media_usage(data[1]+256*data[2]);
}
// The legacy mapping stores a modifier usage, not a HID modifier bitmask.
// Combining modifiers or using the unused trailing bytes is unverified.
static inline int shortcut_mapping(unsigned int modifier,const uint8_t *key,uint8_t out[24]) {
 if(modifier<0xe0 || modifier>0xe7 || !mapping_valid(key) || key[0]!=7 || key[1] || !key[2])return 0;
 memcpy(out,key,24);out[1]=(uint8_t)modifier;return 1;
}
static inline int zero_mapping(const uint8_t *data) {static const uint8_t zero[24]={0};return !memcmp(data,zero,24);}
static inline int matches_readback(unsigned int key,const uint8_t *target,const uint8_t *actual) {
 if(!memcmp(target,actual,24))return 1;
 uint8_t def[24];default_mapping(key,def);
 return !memcmp(target,def,24) && zero_mapping(actual);
}
static inline int parse_hex(const char *s,uint8_t *out,unsigned int n) {
 if(strlen(s)!=2*n)return 0;
 for(unsigned int i=0;i<n;i++){
  unsigned int v=0;
  for(unsigned int j=0;j<2;j++){
   char c=s[i*2+j];unsigned int d;
   if(c>='0'&&c<='9')d=c-'0';else if(c>='a'&&c<='f')d=c-'a'+10;else if(c>='A'&&c<='F')d=c-'A'+10;else return 0;
   v=(v<<4)|d;
  }out[i]=(uint8_t)v;
 }return 1;
}
#endif
