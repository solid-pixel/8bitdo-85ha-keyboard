#ifndef BD85_MACRO_H
#define BD85_MACRO_H
#include "Mapping.h"
#define MACRO_MAX_EVENTS 128
#define MACRO_MAX_BYTES (4+3*MACRO_MAX_EVENTS)
// Individual replacement acknowledged success but failed independent readback.
// Only the separate, explicitly approved full-profile recovery has been verified.
static inline int macro_writes_enabled(void){return 0;}
// A macro write can reallocate the whole table. Do not mutate a table we cannot back up.
static inline int macro_list_writable(const uint8_t *p,unsigned n){
 if(n!=33||p[0]!=0x54||p[1]!=0x82||p[32])return 0;uint8_t seen[256]={0};
 for(unsigned i=2;i+3<32;i+=4){if(!p[i])break;unsigned size=p[i+1]+256u*p[i+2];
  if(seen[p[i]]||!physical_key(p[i])||size<7||size>MACRO_MAX_BYTES||(size-4)%3||!p[i+3]||p[i+3]>28||p[i+3]%2)return 0;seen[p[i]]=1;
 }return 1;
}
static inline int macro_name_valid(const uint8_t *p,unsigned n){
 if(!n||n>28||n%2)return 0;
 for(unsigned i=0;i<n;i+=2){unsigned u=(p[i]<<8)|p[i+1];if(!u)return 0;if(u>=0xd800&&u<=0xdbff){if(i+3>=n)return 0;unsigned v=(p[i+2]<<8)|p[i+3];if(v<0xdc00||v>0xdfff)return 0;i+=2;}else if(u>=0xdc00&&u<=0xdfff)return 0;}
 return 1;
}
static inline int macro_valid(const uint8_t *p,unsigned n){
 if(n<7||n>MACRO_MAX_BYTES||p[0]!=1||n!=4+3u*p[3]||!p[3])return 0;
 unsigned repeat=p[1]+256u*p[2];if(!repeat||repeat>100)return 0;
 uint8_t held[256]={0};unsigned duration=0,normal=0,presses=0;
 for(unsigned i=4;i<n;i+=3){unsigned action=p[i],key=p[i+1]+256u*p[i+2];
  if(action==0x0f){if(key>10000)return 0;duration+=key;continue;}
  int modifier=action==0x83||action==3;
  if(!(modifier?(key>=0xe0&&key<=0xe7):(key>=4&&key<=0x73)) || (action!=0x81&&action!=1&&action!=0x83&&action!=3))return 0;
  if(action&0x80){if(held[key])return 0;held[key]=1;presses++;if(!modifier&&++normal>6)return 0;}
  else{if(!held[key])return 0;held[key]=0;if(!modifier)normal--;}
 }
 for(unsigned i=0;i<256;i++)if(held[i])return 0;
 return presses>0 && (duration+presses*10)*repeat<=60000;
}
// Official JPMacroView passes the saved event count to ClearMacro, not a constant.
// Only construct deletion for a completely decoded, validated saved definition.
static inline int macro_remove_packet(uint8_t key,const uint8_t *data,unsigned n,uint8_t out[33]){
 if(!physical_key(key)||!macro_valid(data,n))return 0;
 memset(out,0,33);out[0]=0x52;out[1]=0x77;out[2]=key;out[3]=data[3];return 1;
}
// Writes keep event triplets intact: 4-byte header + 7 events, then 8 events/frame.
static inline unsigned macro_packet(uint8_t key,const uint8_t *data,unsigned n,unsigned offset,uint8_t out[33]){
 if(!physical_key(key)||!macro_valid(data,n)||offset>=n||(offset&&((offset-4)%3)))return 0;
 unsigned size=offset?24:25;if(size>n-offset)size=n-offset;
 memset(out,0,33);out[0]=0x52;out[1]=0x76;out[2]=key;out[3]=(offset+size<n);out[4]=offset&255;out[5]=offset>>8;out[6]=size;memcpy(out+7,data+offset,size);return size;
}
#endif
